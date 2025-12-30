//
//  PasteeApp.swift
//  Pastee
//
//  Pastee - Clipboard Manager for macOS
//

import SwiftUI
import AppKit

@main
struct PasteeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popupWindow: PopupWindow?
    var loginWindow: NSWindow?
    var settingsWindow: NSPanel?
    var searchWindow: NSPanel?
    
    let authService = AuthService.shared
    let clipboardWatcher = ClipboardWatcher.shared
    let hotkeyService = HotkeyService.shared
    let webSocketService = WebSocketService.shared
    let settingsManager = SettingsManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保单实例运行
        guard SingleInstanceManager.shared.ensureSingleInstance() else {
            NSApp.terminate(nil)
            return
        }
        
        // 设置菜单栏图标
        setupStatusBar()
        
        // 注册URL Scheme处理
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        
        // 检查登录状态
        if authService.isLoggedIn {
            // 已登录，启动应用
            startApp()
        } else {
            // 未登录，显示登录窗口
            showLoginWindow()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher.stop()
        webSocketService.disconnect()
        hotkeyService.unregister()
    }
    
    // MARK: - Setup
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pastee")
            button.image?.isTemplate = true
            // 单击打开窗口
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // 右键：显示菜单
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show Pastee", action: #selector(showPopup), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Search...", action: #selector(showSearch), keyEquivalent: "f"))
            menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Pastee", action: #selector(quit), keyEquivalent: "q"))
            
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            // 点击后清除菜单，以便下次左键可以正常触发
            DispatchQueue.main.async {
                self.statusItem?.menu = nil
            }
        } else {
            // 左键：打开/关闭窗口
            togglePopup()
        }
    }
    
    func startApp() {
        // 启动剪贴板监控
        clipboardWatcher.start()
        
        // 注册全局快捷键
        let settings = settingsManager.load()
        hotkeyService.register(hotkey: settings.hotkey)
        
        hotkeyService.onHotkeyPressed = { [weak self] in
            self?.togglePopup()
        }
        
        // 连接WebSocket
        if let token = authService.getToken() {
            let deviceId = authService.getDeviceId()
            webSocketService.connect(token: token, deviceId: deviceId)
        }
        
        // 检查更新
        Task {
            await UpdateService.shared.checkForUpdate()
        }
        
        // 程序启动后显示主窗口
        showPopup()
    }
    
    // MARK: - Window Management
    
    @objc func showPopup() {
        if popupWindow == nil {
            popupWindow = PopupWindow()
        }
        popupWindow?.showPopup()
    }
    
    func hidePopup() {
        popupWindow?.hidePopup()
    }
    
    @objc func togglePopup() {
        if popupWindow?.isVisible == true {
            hidePopup()
        } else {
            showPopup()
        }
    }
    
    func showLoginWindow() {
        if loginWindow == nil {
            let loginView = LoginView {
                // 登录成功回调
                self.loginWindow?.close()
                self.loginWindow = nil
                self.startApp()
                self.showPopup()
            }
            
            loginWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 650),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            loginWindow?.titlebarAppearsTransparent = true
            loginWindow?.titleVisibility = .hidden
            loginWindow?.isMovableByWindowBackground = true
            loginWindow?.backgroundColor = .clear
            loginWindow?.center()
            loginWindow?.contentView = NSHostingView(rootView: loginView)
        }
        
        loginWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView { [weak self] in
                // 登出回调
                self?.authService.logout()
                self?.clipboardWatcher.stop()
                self?.webSocketService.disconnect()
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
                self?.popupWindow?.close()
                self?.popupWindow = nil
                self?.showLoginWindow()
            }
            
            settingsWindow = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 650),
                styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.isMovableByWindowBackground = true
            settingsWindow?.backgroundColor = .clear
            settingsWindow?.isOpaque = false
            settingsWindow?.hasShadow = true
            settingsWindow?.level = .floating
            settingsWindow?.center()
            let hostingView = NSHostingView(rootView: settingsView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            settingsWindow?.contentView = hostingView
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showSearch() {
        if searchWindow == nil {
            let searchView = SearchView { [weak self] item in
                // 选择项目回调
                self?.copyToClipboard(item)
                self?.searchWindow?.close()
            }
            
            searchWindow = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
                styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            searchWindow?.isMovableByWindowBackground = true
            searchWindow?.backgroundColor = .clear
            searchWindow?.isOpaque = false
            searchWindow?.hasShadow = true
            searchWindow?.level = .floating
            searchWindow?.center()
            let hostingView = NSHostingView(rootView: searchView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            searchWindow?.contentView = hostingView
        }
        
        searchWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func copyToClipboard(_ item: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if item.contentType == "image", let imageData = item.displayImageData {
            if let data = Data(base64Encoded: imageData), let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        } else if let content = item.content {
            pasteboard.setString(content, forType: .string)
        }
        
        // 如果设置了粘贴后隐藏
        let settings = settingsManager.load()
        if settings.hideAfterPaste {
            hidePopup()
        }
    }
    
    @objc func quit() {
        NSApp.terminate(nil)
    }
    
    // MARK: - URL Scheme Handler
    
    @objc func handleURL(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString),
              url.scheme == "pastee",
              url.host == "oauth",
              url.path == "/callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            return
        }
        
        // 保存token并完成登录
        authService.saveToken(token)
        NotificationCenter.default.post(name: .oauthLoginCompleted, object: token)
        
        // 关闭登录窗口并启动应用
        DispatchQueue.main.async {
            self.loginWindow?.close()
            self.loginWindow = nil
            self.startApp()
            self.showPopup()
        }
    }
}

// MARK: - 通知名称
extension Notification.Name {
    static let oauthLoginCompleted = Notification.Name("oauthLoginCompleted")
    static let globalHotkeyPressed = Notification.Name("globalHotkeyPressed")
    static let clipboardChanged = Notification.Name("clipboardChanged")
    static let webSocketMessage = Notification.Name("webSocketMessage")
    static let pasteToFocusedApp = Notification.Name("pasteToFocusedApp")
}

// MARK: - 单实例管理器
class SingleInstanceManager {
    static let shared = SingleInstanceManager()
    
    func ensureSingleInstance() -> Bool {
        guard let bundleId = Bundle.main.bundleIdentifier else { return true }
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        
        if runningApps.count > 1 {
            // 已有实例运行，激活它
            runningApps.first?.activate(options: .activateIgnoringOtherApps)
            return false
        }
        
        return true
    }
}

