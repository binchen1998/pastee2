# Pastee macOS 原生应用开发指南

## 概述

本文档详细描述 Pastee 剪贴板管理应用的所有功能、API 接口和实现细节，用于在 macOS 上使用 Swift/SwiftUI 和 Xcode 进行原生开发。

**目标**: 实现与 Windows 版本完全一致的功能和 UI 风格。

---

## 1. 应用基础信息

### 1.1 应用标识
- **App Name**: Pastee
- **Bundle ID**: 建议 `com.pastee.app` 或 `im.pastee.app`
- **最低系统版本**: macOS 12.0+
- **架构**: Universal (Intel + Apple Silicon)

### 1.2 API 基础配置
```swift
let API_BASE_URL = "https://api.pastee-app.com"
let WS_BASE_URL = "wss://api.pastee-app.com/ws"
```

### 1.3 本地存储路径
```swift
// 使用 Application Support 目录
let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let pasteeDir = appSupportDir.appendingPathComponent("Pastee")

// 文件结构
// ~/Library/Application Support/Pastee/
//   ├── auth.token          // JWT Token
//   ├── device.id           // 设备 ID
//   ├── settings.json       // 用户设置
//   ├── clipboard.json      // 本地剪贴板数据缓存
//   └── images/             // 图片缓存目录
```

---

## 2. 用户认证模块

### 2.1 数据模型

```swift
struct AuthResult {
    let success: Bool
    let token: String?
    let email: String?
    let errorMessage: String?
}

struct UserInfo: Codable {
    let id: Int
    let email: String
    let storage_used: Int
    let storage_limit: Int
    let is_verified: Bool
    let created_at: String
}
```

### 2.2 设备 ID 管理

每个设备需要唯一的 Device ID，首次启动时生成并永久保存：

```swift
func getOrCreateDeviceId() -> String {
    let deviceIdFile = pasteeDir.appendingPathComponent("device.id")
    
    if let existingId = try? String(contentsOf: deviceIdFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
        return existingId
    }
    
    // 生成格式: macos-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    let newId = "macos-\(UUID().uuidString.lowercased())"
    try? newId.write(to: deviceIdFile, atomically: true, encoding: .utf8)
    return newId
}
```

### 2.3 Token 管理

```swift
// 保存 Token
func saveToken(_ token: String) {
    let tokenFile = pasteeDir.appendingPathComponent("auth.token")
    try? token.write(to: tokenFile, atomically: true, encoding: .utf8)
}

// 读取 Token
func getSavedToken() -> String? {
    let tokenFile = pasteeDir.appendingPathComponent("auth.token")
    return try? String(contentsOf: tokenFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
}

// 清除 Token (登出)
func logout() {
    let tokenFile = pasteeDir.appendingPathComponent("auth.token")
    try? FileManager.default.removeItem(at: tokenFile)
}
```

### 2.4 登录 API

**请求**:
```
POST /auth/token
Content-Type: application/x-www-form-urlencoded

username=user@example.com&password=userpassword
```

**成功响应** (200):
```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "bearer"
}
```

**失败响应**:
- 401: 用户名或密码错误
- 403: 账户未验证 `{"detail": "email_not_verified"}`
- 422: 参数验证失败

### 2.5 注册 API

**请求**:
```
POST /auth/register
Content-Type: application/json

{
    "email": "user@example.com",
    "password": "password123"
}
```

**成功响应** (200):
```json
{
    "message": "Registration successful. Please check your email for verification code.",
    "email": "user@example.com"
}
```

**失败响应**:
- 400: `{"detail": "Email already registered"}`
- 422: 参数验证失败

### 2.6 邮箱验证 API

**验证码验证**:
```
POST /auth/verify-email
Content-Type: application/json

{
    "email": "user@example.com",
    "verification_code": "123456"
}
```

**重发验证码**:
```
POST /auth/resend-verification
Content-Type: application/json

{
    "email": "user@example.com"
}
```

### 2.7 验证 Token / 获取用户信息

**请求**:
```
GET /auth/me
Authorization: Bearer <token>
```

**成功响应** (200):
```json
{
    "id": 123,
    "email": "user@example.com",
    "storage_used": 1048576,
    "storage_limit": 104857600,
    "is_verified": true,
    "created_at": "2024-01-15T10:30:00Z"
}
```

**失败响应**:
- 401: Token 无效或过期

### 2.8 Google OAuth 登录

**流程**:
1. 打开系统浏览器访问授权 URL
2. 用户在浏览器完成 Google 登录
3. 后端重定向到自定义 URL Scheme: `pastee://oauth/callback?token=JWT_TOKEN`
4. macOS 应用通过 URL Scheme 接收 Token
5. 保存 Token 并完成登录

**授权 URL**:
```
GET /auth/oauth/google/authorize?redirect_uri=pastee://oauth/callback
```

**macOS URL Scheme 注册** (Info.plist):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>Pastee OAuth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>pastee</string>
        </array>
    </dict>
</array>
```

**处理回调**:
```swift
// AppDelegate 或 App 中
func application(_ application: NSApplication, open urls: [URL]) {
    guard let url = urls.first,
          url.scheme == "pastee",
          url.host == "oauth",
          url.path == "/callback",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
        return
    }
    
    // 保存 token 并完成登录
    saveToken(token)
    NotificationCenter.default.post(name: .oauthLoginCompleted, object: token)
}
```

---

## 3. 剪贴板数据模块

### 3.1 数据模型

```swift
struct ClipboardEntry: Codable, Identifiable {
    let id: String  // 可能是数字字符串或 UUID
    var content_type: String  // "text", "url", "image"
    var content: String?
    var file_path: String?
    var file_name: String?
    var thumbnail: String?  // Base64 编码的缩略图
    var original_deleted: Bool?
    var created_at: Date
    var is_bookmarked: Bool
    
    // 本地状态 (不序列化到服务器)
    var isUploading: Bool = false
    var uploadFailed: Bool = false
    var displayImageData: Data?  // 用于 UI 显示
    var isThumbnail: Bool = true
}

struct ClipboardListResponse: Codable {
    let items: [ClipboardEntry]
    let total: Int
    let page: Int
    let page_size: Int
    let has_more: Bool
}
```

### 3.2 获取剪贴板列表

**请求**:
```
GET /clipboard/items?page=1&page_size=50&category=all
Authorization: Bearer <token>
```

**Query 参数**:
- `page`: 页码，从 1 开始
- `page_size`: 每页数量，默认 50
- `category`: 分类筛选
  - `all`: 所有项目
  - `bookmarked`: 收藏的项目
  - `{category_name}`: 自定义分类名

**响应**:
```json
{
    "items": [
        {
            "id": "12345",
            "content_type": "text",
            "content": "Hello World",
            "created_at": "2024-01-15T10:30:00Z",
            "is_bookmarked": false
        },
        {
            "id": "12346",
            "content_type": "image",
            "content": "base64_thumbnail_data...",
            "file_name": "screenshot.png",
            "created_at": "2024-01-15T10:31:00Z",
            "is_bookmarked": true
        }
    ],
    "total": 150,
    "page": 1,
    "page_size": 50,
    "has_more": true
}
```

### 3.3 上传剪贴板项

**文本/URL 上传**:
```
POST /clipboard/items
Authorization: Bearer <token>
Content-Type: multipart/form-data

content_type: text
content: "复制的文本内容"
device_id: macos-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
created_at: 2024-01-15T10:30:00.000Z
```

**图片上传**:
```
POST /clipboard/items
Authorization: Bearer <token>
Content-Type: multipart/form-data

content_type: image
device_id: macos-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
created_at: 2024-01-15T10:30:00.000Z
file: <binary image data>
```

**成功响应** (200/201):
```json
{
    "id": "12347",
    "content_type": "text",
    "content": "复制的文本内容",
    "created_at": "2024-01-15T10:30:00Z",
    "is_bookmarked": false
}
```

**特殊响应**:
- **409 Conflict**: `{"detail": "duplicate_item"}` - 重复项，视为成功，不显示错误

### 3.4 删除剪贴板项

**请求**:
```
DELETE /clipboard/items/{id}
Authorization: Bearer <token>
```

**响应**: 200 OK

### 3.5 更新剪贴板项

**更新书签状态**:
```
PATCH /clipboard/items/{id}
Authorization: Bearer <token>
Content-Type: application/json

{
    "is_bookmarked": true
}
```

**更新文本内容**:
```
PATCH /clipboard/items/{id}
Authorization: Bearer <token>
Content-Type: application/json

{
    "content": "修改后的文本"
}
```

### 3.6 获取原图

**请求**:
```
GET /clipboard/items/{id}/original
Authorization: Bearer <token>
```

**响应**: 二进制图片数据

### 3.7 搜索

**请求**:
```
GET /clipboard/items/search?q=关键词&page=1&page_size=50
Authorization: Bearer <token>
```

---

## 4. 分类管理模块

### 4.1 数据模型

```swift
struct Category: Codable, Identifiable {
    let id: Int
    let name: String
    let item_count: Int?
    let created_at: String?
}
```

### 4.2 获取分类列表

**请求**:
```
GET /clipboard/categories
Authorization: Bearer <token>
```

**响应**:
```json
[
    {"id": 1, "name": "工作", "item_count": 15},
    {"id": 2, "name": "代码", "item_count": 8}
]
```

### 4.3 创建分类

**请求**:
```
POST /clipboard/categories
Authorization: Bearer <token>
Content-Type: application/json

{
    "name": "新分类"
}
```

### 4.4 更新分类

**请求**:
```
PUT /clipboard/categories/{id}
Authorization: Bearer <token>
Content-Type: application/json

{
    "name": "重命名分类"
}
```

### 4.5 删除分类

**请求**:
```
DELETE /clipboard/categories/{id}
Authorization: Bearer <token>
```

### 4.6 添加项目到分类

**请求**:
```
POST /clipboard/categories/{category_id}/items/{item_id}
Authorization: Bearer <token>
```

---

## 5. WebSocket 实时同步

### 5.1 连接

**URL 格式**:
```
wss://api.pastee-app.com/ws/{token}/{device_id}
```

### 5.2 心跳机制

**客户端发送 (每 30 秒)**:
```json
{"type": "ping"}
```

**服务端响应**:
```json
{"type": "pong"}
```

**超时处理**:
- 发送 ping 后 10 秒未收到 pong，判定连接断开
- 触发自动重连

### 5.3 重连机制

```swift
class WebSocketService {
    private var reconnectInterval: TimeInterval = 5.0  // 5秒重连间隔
    private var isIntentionallyClosed = false
    
    func scheduleReconnect() {
        guard !isIntentionallyClosed else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectInterval) { [weak self] in
            self?.connect()
        }
    }
}
```

### 5.4 事件类型

**新增项目**:
```json
{
    "event": "new_item",  // 或 "type": "item_created"
    "data": {
        "id": "12347",
        "content_type": "text",
        "content": "新复制的内容",
        "created_at": "2024-01-15T10:30:00Z",
        "is_bookmarked": false
    }
}
```

**更新项目**:
```json
{
    "event": "update_item",
    "data": {
        "id": "12347",
        "content": "更新后的内容",
        "is_bookmarked": true
    }
}
```

**删除项目**:
```json
{
    "event": "delete_item",
    "data": {
        "id": "12347"
    }
}
```
或
```json
{
    "event": "delete_item",
    "data": "12347"
}
```

**全量同步请求**:
```json
{
    "event": "sync"
}
```

### 5.5 完整实现示例

```swift
class WebSocketService: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private var token: String?
    private var deviceId: String?
    private var heartbeatTimer: Timer?
    private var pongTimeoutTimer: Timer?
    private var isIntentionallyClosed = false
    
    var onMessage: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    
    func connect(token: String, deviceId: String) {
        self.token = token
        self.deviceId = deviceId
        isIntentionallyClosed = false
        
        let url = URL(string: "\(WS_BASE_URL)/\(token)/\(deviceId)")!
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                default:
                    break
                }
                self?.receiveMessage()
            case .failure:
                self?.handleDisconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        // 处理 pong
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           json["type"] as? String == "pong" {
            pongTimeoutTimer?.invalidate()
            return
        }
        
        DispatchQueue.main.async {
            self.onMessage?(text)
        }
    }
    
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        let ping = try? JSONSerialization.data(withJSONObject: ["type": "ping"])
        if let ping = ping {
            webSocket?.send(.data(ping)) { _ in }
        }
        
        // 设置 pong 超时
        pongTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.handleDisconnect()
        }
    }
    
    func disconnect() {
        isIntentionallyClosed = true
        heartbeatTimer?.invalidate()
        pongTimeoutTimer?.invalidate()
        webSocket?.cancel(with: .goingAway, reason: nil)
    }
    
    private func handleDisconnect() {
        heartbeatTimer?.invalidate()
        pongTimeoutTimer?.invalidate()
        
        DispatchQueue.main.async {
            self.onDisconnected?()
        }
        
        if !isIntentionallyClosed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self, let token = self.token, let deviceId = self.deviceId else { return }
                self.connect(token: token, deviceId: deviceId)
            }
        }
    }
    
    // URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.onConnected?()
            self.startHeartbeat()
        }
    }
}
```

---

## 6. 剪贴板监控

### 6.1 macOS 剪贴板监控实现

```swift
class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    
    var onNewContent: ((ClipboardEntry) -> Void)?
    
    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        // 检查图片
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            handleImage(image)
            return
        }
        
        // 检查文本
        if let string = pasteboard.string(forType: .string) {
            handleText(string)
            return
        }
    }
    
    private func handleText(_ text: String) {
        let entry = ClipboardEntry(
            id: UUID().uuidString,
            content_type: isURL(text) ? "url" : "text",
            content: text,
            created_at: Date(),
            is_bookmarked: false
        )
        onNewContent?(entry)
    }
    
    private func handleImage(_ image: NSImage) {
        // 保存图片到本地临时文件
        let tempPath = saveImageToTemp(image)
        
        let entry = ClipboardEntry(
            id: UUID().uuidString,
            content_type: "image",
            file_path: tempPath,
            created_at: Date(),
            is_bookmarked: false
        )
        onNewContent?(entry)
    }
    
    private func isURL(_ text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.count == 1 && matches.first?.range == range
    }
}
```

### 6.2 内容去重

使用内容签名防止重复捕获：

```swift
class ContentDeduplicator {
    private var lastSignature: String?
    
    func isDuplicate(_ entry: ClipboardEntry) -> Bool {
        let signature = generateSignature(entry)
        
        if signature == lastSignature {
            return true
        }
        
        lastSignature = signature
        return false
    }
    
    private func generateSignature(_ entry: ClipboardEntry) -> String {
        switch entry.content_type {
        case "text", "url":
            return "text:\(entry.content?.hashValue ?? 0)"
        case "image":
            // 使用文件大小和修改时间作为签名
            if let path = entry.file_path,
               let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                let size = attrs[.size] as? Int ?? 0
                return "image:\(size)"
            }
            return "image:\(UUID().uuidString)"
        default:
            return UUID().uuidString
        }
    }
}
```

---

## 7. 全局快捷键

### 7.1 注册全局快捷键

```swift
import Carbon

class HotkeyService {
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    
    var onHotkeyPressed: (() -> Void)?
    
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        // 默认: Command + Shift + V
        // keyCode: 9 (V)
        // modifiers: cmdKey | shiftKey
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("PSTE".fourCharCode)
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                NotificationCenter.default.post(name: .globalHotkeyPressed, object: nil)
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        guard status == noErr else { return false }
        
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        return registerStatus == noErr
    }
    
    func unregister() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

extension String {
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf8.prefix(4) {
            result = result << 8 + FourCharCode(char)
        }
        return result
    }
}
```

### 7.2 支持的快捷键组合

- `Command + Shift + V` (推荐默认)
- `Command + Option + V`
- `Control + Shift + V`
- 自定义组合

### 7.3 快捷键设置持久化

```swift
struct AppSettings: Codable {
    var hotkey: String = "Command + Shift + V"
    var hideAfterPaste: Bool = true
    var launchAtLogin: Bool = false
}
```

---

## 8. 草稿 (Drafts) 功能

### 8.1 草稿定义

当剪贴板项上传失败时，标记为草稿 (`uploadFailed = true`)，保存到本地存储。

### 8.2 草稿管理

```swift
class DraftManager {
    private let draftFile: URL
    
    init() {
        draftFile = pasteeDir.appendingPathComponent("clipboard.json")
    }
    
    func saveDraft(_ entry: ClipboardEntry) {
        var drafts = loadDrafts()
        drafts.removeAll { $0.id == entry.id }
        drafts.append(entry)
        save(drafts)
    }
    
    func removeDraft(_ entry: ClipboardEntry) {
        var drafts = loadDrafts()
        drafts.removeAll { $0.id == entry.id }
        save(drafts)
    }
    
    func loadDrafts() -> [ClipboardEntry] {
        guard let data = try? Data(contentsOf: draftFile),
              let entries = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else {
            return []
        }
        return entries.filter { $0.uploadFailed }
    }
    
    func clearAllDrafts() {
        var entries = loadDrafts()
        entries.removeAll { $0.uploadFailed }
        save(entries)
    }
    
    var draftCount: Int {
        loadDrafts().count
    }
}
```

### 8.3 重试上传

草稿项显示"重试"按钮，点击后重新尝试上传。

### 8.4 删除草稿

删除草稿时**不调用服务器 API**，只从本地移除。

---

## 9. 自动更新模块

### 9.1 检查更新 API

**请求**:
```
POST /version/check
Authorization: Bearer <token>
Content-Type: application/json

{
    "current_version": "3.6.0"
}
```

**响应**:
```json
{
    "update_available": true,
    "latest_version": "3.7.0",
    "is_mandatory": false,
    "release_notes": "Bug fixes and improvements",
    "download_url": "https://static1.cxy61.com/Pastee-Setup-3.7.0.dmg"
}
```

### 9.2 更新流程

1. 登录后立即检查一次
2. 每 6 小时自动检查
3. 有更新时显示弹窗
4. 强制更新时禁用关闭按钮
5. 下载 .dmg 文件并提示用户安装

### 9.3 macOS 自动更新实现

```swift
class UpdateService {
    func checkForUpdate() async throws -> VersionCheckResponse? {
        guard let token = getSavedToken() else { return nil }
        
        let url = URL(string: "\(API_BASE_URL)/version/check")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["current_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(VersionCheckResponse.self, from: data)
    }
    
    func downloadUpdate(url: String, progress: @escaping (Double) -> Void) async throws -> URL {
        // 下载到临时目录
        let downloadURL = URL(string: url)!
        let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
        
        // 移动到 Downloads 目录
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destURL = downloadsDir.appendingPathComponent(downloadURL.lastPathComponent)
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        
        return destURL
    }
    
    func openDMG(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
```

---

## 10. 设置模块

### 10.1 设置项

| 设置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| hotkey | String | "Command + Shift + V" | 全局快捷键 |
| hideAfterPaste | Bool | true | 粘贴后自动隐藏窗口 |
| launchAtLogin | Bool | false | 开机自启动 |

### 10.2 设置持久化

```swift
class SettingsManager {
    private let settingsFile: URL
    
    init() {
        settingsFile = pasteeDir.appendingPathComponent("settings.json")
    }
    
    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsFile),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsFile)
    }
}
```

### 10.3 开机自启动 (macOS)

```swift
import ServiceManagement

func setLaunchAtLogin(_ enabled: Bool) {
    if #available(macOS 13.0, *) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    } else {
        // 旧版本使用 SMLoginItemSetEnabled
        SMLoginItemSetEnabled("com.pastee.app.LaunchHelper" as CFString, enabled)
    }
}
```

---

## 11. 管理员面板 (仅 admin@pastee.im)

### 11.1 权限检查

```swift
func isAdmin(_ email: String?) -> Bool {
    return email?.lowercased() == "admin@pastee.im"
}
```

### 11.2 仪表盘 API

**请求**:
```
GET /admin/dashboard
Authorization: Bearer <token>
```

**响应**:
```json
{
    "summary": {
        "total_users": 1500,
        "today_registrations": 25,
        "today_active": 320,
        "week_avg_registrations": 18.5,
        "week_avg_active": 280.3
    },
    "today": {
        "date": "2024-01-15",
        "new_registrations": 25,
        "active_users": 320,
        "total_users": 1500
    },
    "yesterday": {
        "date": "2024-01-14",
        "new_registrations": 22,
        "active_users": 310,
        "total_users": 1475
    },
    "growth_rates": {
        "registrations": 13.6,
        "active_users": 3.2
    },
    "recent_week": [
        {"date": "2024-01-15", "new_registrations": 25, "active_users": 320, "total_users": 1500},
        // ... 7 天数据
    ]
}
```

### 11.3 用户管理 API

**获取用户列表**:
```
GET /admin/users?page=1&page_size=20&search=keyword
Authorization: Bearer <token>
```

**删除用户**:
```
DELETE /admin/users/{user_id}
Authorization: Bearer <token>
```

### 11.4 版本管理 API

**获取版本列表**:
```
GET /version/versions
Authorization: Bearer <token>
```

**发布新版本**:
```
POST /version/versions
Authorization: Bearer <token>
Content-Type: application/json

{
    "version": "3.7.0",
    "download_url": "https://...",
    "release_notes": "更新说明",
    "is_mandatory": false
}
```

**删除版本**:
```
DELETE /version/versions/{id}
Authorization: Bearer <token>
```

---

## 12. UI 组件

### 12.1 主窗口 (悬浮面板)

- 类型: `NSPanel` with `.nonactivatingPanel` style
- 位置: 屏幕右下角
- 尺寸: 约 400x500，可调整
- 特性:
  - 悬浮于其他窗口之上
  - 点击外部自动隐藏
  - 顶部区域可拖动移动位置

### 12.2 窗口行为

```swift
class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = NSColor(named: "BackgroundColor")
    }
}
```

### 12.3 项目卡片样式

- 背景: 深色 (#2a2a3a)
- 圆角: 8px
- 内边距: 12px
- 文本颜色: 
  - 主要文本: 白色
  - 次要文本: 灰色 (#8e8e93)
- 操作按钮: 悬停时显示

### 12.4 状态指示

- 上传中: 显示 Loading 图标
- 上传失败: 显示红色 "Failed" 标签和重试按钮
- 已收藏: 显示星标

### 12.5 深色主题配色

```swift
// Colors.xcassets 中定义
extension NSColor {
    static let background = NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)  // #1c1c21
    static let surface = NSColor(red: 0.16, green: 0.16, blue: 0.23, alpha: 1)     // #2a2a3a
    static let accent = NSColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1)      // #4a90e2
    static let textPrimary = NSColor.white
    static let textSecondary = NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1) // #8e8e93
    static let border = NSColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1)      // #3d3d42
    static let delete = NSColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1)      // #e74c3c
}
```

---

## 13. 菜单栏图标

### 13.1 状态栏项

```swift
class StatusBarController {
    private var statusItem: NSStatusItem!
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true  // 自动适应系统主题
            button.action = #selector(togglePopup)
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Pastee", action: #selector(showPopup), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Pastee", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
}
```

### 13.2 菜单项

- Show Pastee (打开主窗口)
- Settings... (打开设置)
- Quit Pastee (退出应用)

---

## 14. 单实例运行

确保只有一个应用实例运行：

```swift
class SingleInstanceManager {
    static let shared = SingleInstanceManager()
    
    func ensureSingleInstance() -> Bool {
        let bundleId = Bundle.main.bundleIdentifier!
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        
        if runningApps.count > 1 {
            // 已有实例运行，激活它并退出当前实例
            runningApps.first?.activate(options: .activateIgnoringOtherApps)
            return false
        }
        
        return true
    }
}

// 在 AppDelegate 中
func applicationDidFinishLaunching(_ notification: Notification) {
    guard SingleInstanceManager.shared.ensureSingleInstance() else {
        NSApp.terminate(nil)
        return
    }
    
    // 继续正常启动...
}
```

---

## 15. HTTP 请求通用配置

### 15.1 超时设置

所有 HTTP 请求超时时间: **10 秒**

```swift
class APIService {
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }
}
```

### 15.2 请求头

```swift
func createRequest(url: URL, method: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    
    if let token = getSavedToken() {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    return request
}
```

### 15.3 错误处理

```swift
enum APIError: Error {
    case networkError(Error)
    case timeout
    case unauthorized  // 401
    case forbidden     // 403
    case notFound      // 404
    case conflict      // 409 (重复项)
    case serverError   // 5xx
    case unknown(Int)
    
    var localizedDescription: String {
        switch self {
        case .timeout:
            return "Request timed out. Please check your network connection."
        case .unauthorized:
            return "Session expired. Please login again."
        // ...
        }
    }
}
```

---

## 16. 支持信息

在设置页面底部显示：

- **Support Email**: binary.chen@gmail.com
- 点击打开默认邮件客户端

---

## 17. 开发注意事项

### 17.1 权限配置 (Entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### 17.2 Info.plist 关键配置

```xml
<key>LSUIElement</key>
<true/>  <!-- 隐藏 Dock 图标 -->

<key>NSAppleEventsUsageDescription</key>
<string>Pastee needs access to control other applications for pasting.</string>
```

### 17.3 代码签名

- 使用 Developer ID 签名以避免 Gatekeeper 警告
- 进行公证 (Notarization) 以获得最佳用户体验

---

## 18. 测试清单

- [ ] 用户注册和登录
- [ ] Google OAuth 登录
- [ ] 邮箱验证流程
- [ ] 剪贴板文本捕获
- [ ] 剪贴板图片捕获
- [ ] 实时同步 (WebSocket)
- [ ] 心跳和自动重连
- [ ] 分类管理
- [ ] 搜索功能
- [ ] 收藏功能
- [ ] 草稿管理
- [ ] 全局快捷键
- [ ] 设置持久化
- [ ] 开机自启动
- [ ] 自动更新检查
- [ ] 管理员面板 (admin@pastee.im)
- [ ] 单实例运行
- [ ] URL Scheme 处理

---

## 版本历史

- **3.6.0**: 当前 Windows 版本功能基准

---

*文档最后更新: 2024*


