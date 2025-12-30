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
        
        // 注册通知监听
        setupNotifications()
        
        // 检查登录状态
        if authService.isLoggedIn {
            // 已登录，启动应用
            startApp()
        } else {
            // 未登录，显示登录窗口
            showLoginWindow()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: .showSettingsWindow,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSearch),
            name: .showSearchWindow,
            object: nil
        )
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
        // 检查辅助功能权限
        checkAccessibilityPermission()
        
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
        // 使用 DispatchQueue 避免在 transaction 中调用 modal
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let settingsView = SettingsView { [weak self] in
                // 登出回调
                NSApp.stopModal()
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
                self?.authService.logout()
                self?.clipboardWatcher.stop()
                self?.webSocketService.disconnect()
                self?.popupWindow?.close()
                self?.popupWindow = nil
                self?.showLoginWindow()
            }
            
            let modalWindow = KeyablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 650),
                styleMask: [.borderless, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            modalWindow.isMovableByWindowBackground = true
            modalWindow.backgroundColor = .clear
            modalWindow.isOpaque = false
            modalWindow.hasShadow = true
            modalWindow.level = .modalPanel
            modalWindow.center()
            
            let hostingView = NSHostingView(rootView: settingsView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            modalWindow.contentView = hostingView
            
            self.settingsWindow = modalWindow
            NSApp.runModal(for: modalWindow)
            self.settingsWindow = nil
        }
    }
    
    @objc func showSearch() {
        // 使用 DispatchQueue 避免在 transaction 中调用 modal
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let searchView = SearchView { [weak self] item in
                // 选择项目回调
                NSApp.stopModal()
                self?.searchWindow?.close()
                self?.searchWindow = nil
                self?.copyToClipboard(item)
            }
            
            let modalWindow = KeyablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
                styleMask: [.borderless, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            modalWindow.isMovableByWindowBackground = true
            modalWindow.backgroundColor = .clear
            modalWindow.isOpaque = false
            modalWindow.hasShadow = true
            modalWindow.level = .modalPanel
            modalWindow.center()
            
            let hostingView = NSHostingView(rootView: searchView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            modalWindow.contentView = hostingView
            
            self.searchWindow = modalWindow
            NSApp.runModal(for: modalWindow)
            self.searchWindow = nil
        }
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
    
    // MARK: - Accessibility Permission
    
    private static let kDontShowAccessibilityPrompt = "dontShowAccessibilityPrompt"
    
    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            // 检查用户是否选择了不再提示
            let dontShow = UserDefaults.standard.bool(forKey: AppDelegate.kDontShowAccessibilityPrompt)
            if !dontShow {
                showAccessibilityPermissionDialog()
            }
        }
    }
    
    private func showAccessibilityPermissionDialog() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        Pastee 需要辅助功能权限才能实现以下功能：
        
        • 点击剪贴板项目后自动粘贴
        • 全局快捷键 (⌘⇧V)
        
        请在系统设置中启用 Pastee 的辅助功能权限。
        """
        alert.alertStyle = .warning
        alert.icon = NSImage(systemSymbolName: "hand.raised.circle.fill", accessibilityDescription: "Permission")
        
        // 添加"不再提示"复选框
        let checkbox = NSButton(checkboxWithTitle: "不再提示", target: nil, action: nil)
        checkbox.state = .off
        alert.accessoryView = checkbox
        
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后再说")
        
        let response = alert.runModal()
        
        // 保存用户的"不再提示"选择
        if checkbox.state == .on {
            UserDefaults.standard.set(true, forKey: AppDelegate.kDontShowAccessibilityPrompt)
        }
        
        if response == .alertFirstButtonReturn {
            // 打开系统设置的辅助功能页面
            openAccessibilitySettings()
        }
    }
    
    private func openAccessibilitySettings() {
        // macOS 13+ 使用新的 URL scheme
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // macOS 12 及更早版本
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        // 同时触发系统的权限请求对话框（会高亮显示应用）
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
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
    static let showSettingsWindow = Notification.Name("showSettingsWindow")
    static let showSearchWindow = Notification.Name("showSearchWindow")
    static let uploadCompleted = Notification.Name("uploadCompleted")
    static let uploadFailed = Notification.Name("uploadFailed")
}

// MARK: - KeyablePanel
// 自定义 NSPanel 子类，允许 borderless 窗口接收键盘输入
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
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

