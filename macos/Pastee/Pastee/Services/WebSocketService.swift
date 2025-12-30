//
//  WebSocketService.swift
//  Pastee
//
//  WebSocket 实时同步服务
//

import Foundation

class WebSocketService: NSObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()
    
    private let wsBaseURL = "wss://api.pastee-app.com/ws"
    
    private var webSocket: URLSessionWebSocketTask?
    private var token: String?
    private var deviceId: String?
    private var heartbeatTimer: Timer?
    private var pongTimeoutTimer: Timer?
    private var isIntentionallyClosed = false
    
    var onMessage: ((WebSocketEvent) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    
    private(set) var isConnected = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Connection
    
    func connect(token: String, deviceId: String) {
        self.token = token
        self.deviceId = deviceId
        isIntentionallyClosed = false
        
        guard let url = URL(string: "\(wsBaseURL)/\(token)/\(deviceId)") else { return }
        
        // 配置 URLSession，禁用超时
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(Int.max)  // 无限制
        config.timeoutIntervalForResource = TimeInterval(Int.max) // 无限制
        config.waitsForConnectivity = true
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        receiveMessage()
        print("⚡️ [WS] Connecting to \(url)")
    }
    
    func disconnect() {
        isIntentionallyClosed = true
        stopHeartbeat()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
    }
    
    func reconnect() {
        guard let token = token, let deviceId = deviceId else { return }
        disconnect()
        isIntentionallyClosed = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.connect(token: token, deviceId: deviceId)
        }
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()
            case .failure:
                self?.handleDisconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // 处理 pong
        if json["type"] as? String == "pong" {
            print("⚡️ [WS] Received pong")
            DispatchQueue.main.async {
                self.pongTimeoutTimer?.invalidate()
                self.pongTimeoutTimer = nil
            }
            return
        }
        
        // 解析事件
        let event = parseEvent(json: json, rawData: data)
        
        DispatchQueue.main.async {
            self.onMessage?(event)
            NotificationCenter.default.post(name: .webSocketMessage, object: event)
        }
    }
    
    private func parseEvent(json: [String: Any], rawData: Data) -> WebSocketEvent {
        let eventType = json["event"] as? String ?? json["type"] as? String ?? ""
        let eventData = json["data"]
        
        switch eventType {
        case "new_item", "item_created":
            if let itemData = eventData as? [String: Any],
               let itemJson = try? JSONSerialization.data(withJSONObject: itemData),
               var item = try? JSONDecoder().decode(ClipboardEntry.self, from: itemJson) {
                item.initializeImageState()
                return .newItem(item)
            }
        case "update_item", "item_updated":
            if let itemData = eventData as? [String: Any],
               let itemJson = try? JSONSerialization.data(withJSONObject: itemData),
               let item = try? JSONDecoder().decode(ClipboardEntry.self, from: itemJson) {
                return .updateItem(item)
            }
        case "delete_item", "item_deleted":
            if let itemId = eventData as? String {
                return .deleteItem(itemId)
            } else if let itemData = eventData as? [String: Any],
                      let itemId = itemData["id"] as? String {
                return .deleteItem(itemId)
            } else if let itemData = eventData as? [String: Any],
                      let itemId = itemData["id"] as? Int {
                return .deleteItem(String(itemId))
            }
        case "sync":
            return .sync
        default:
            break
        }
        
        return .unknown(text: String(data: rawData, encoding: .utf8) ?? "")
    }
    
    // MARK: - Heartbeat
    
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        pongTimeoutTimer?.invalidate()
        pongTimeoutTimer = nil
    }
    
    private func sendPing() {
        let pingMessage = "{\"type\":\"ping\"}"
        
        print("⚡️ [WS] Sending ping")
        webSocket?.send(.string(pingMessage)) { [weak self] error in
            if let error = error {
                print("⚡️ [WS] Ping failed: \(error)")
                self?.handleDisconnect()
                return
            }
            
            // 设置 pong 超时
            DispatchQueue.main.async {
                self?.pongTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                    print("⚡️ [WS] Pong timeout!")
                    self?.handleDisconnect()
                }
            }
        }
    }
    
    // MARK: - Disconnect Handling
    
    private func handleDisconnect() {
        DispatchQueue.main.async {
            self.stopHeartbeat()
            self.isConnected = false
            self.onDisconnected?()
            
            if !self.isIntentionallyClosed {
                // 5秒后重连
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self = self,
                          let token = self.token,
                          let deviceId = self.deviceId,
                          !self.isIntentionallyClosed else { return }
                    self.connect(token: token, deviceId: deviceId)
                }
            }
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("⚡️ [WS] Connected!")
        DispatchQueue.main.async {
            self.isConnected = true
            self.onConnected?()
            self.startHeartbeat()
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("⚡️ [WS] Closed with code: \(closeCode)")
        handleDisconnect()
    }
}

// MARK: - WebSocket Event

enum WebSocketEvent {
    case newItem(ClipboardEntry)
    case updateItem(ClipboardEntry)
    case deleteItem(String)
    case sync
    case unknown(text: String)
}

