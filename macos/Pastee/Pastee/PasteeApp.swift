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
            // 使用自定义 Menu Bar 图标
            if let menuBarImage = NSImage(named: "MenuBarIcon") {
                menuBarImage.isTemplate = true  // 启用 template 模式，自动适应深色/浅色模式
                button.image = menuBarImage
            } else {
                // 备用：使用系统图标
                button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pastee")
                button.image?.isTemplate = true
            }
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
        print("⚡️ [AppDelegate] startApp - Step 1: starting clipboard watcher")
        // 启动剪贴板监控（先启动，不依赖权限检查）
        clipboardWatcher.start()
        
        print("⚡️ [AppDelegate] startApp - Step 2: registering hotkey")
        // 注册全局快捷键
        let settings = settingsManager.load()
        hotkeyService.register(hotkey: settings.hotkey)
        
        hotkeyService.onHotkeyPressed = { [weak self] in
            self?.togglePopup()
        }
        
        print("⚡️ [AppDelegate] startApp - Step 3: connecting WebSocket")
        // 连接WebSocket
        if let token = authService.getToken() {
            let deviceId = authService.getDeviceId()
            webSocketService.connect(token: token, deviceId: deviceId)
        }
        
        print("⚡️ [AppDelegate] startApp - Step 4: checking for updates")
        // 检查更新
        Task {
            await UpdateService.shared.checkForUpdate()
        }
        
        print("⚡️ [AppDelegate] startApp - Step 5: showing popup")
        // 程序启动后显示主窗口
        showPopup()
        
        print("⚡️ [AppDelegate] startApp - Step 6: scheduling accessibility check")
        // 延迟检查辅助功能权限（避免在窗口切换时调用 runModal 导致崩溃）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            print("⚡️ [AppDelegate] startApp - Step 7: checking accessibility permission")
            self?.checkAccessibilityPermission()
            print("⚡️ [AppDelegate] startApp - Step 8: accessibility check done")
        }
        print("⚡️ [AppDelegate] startApp - completed (accessibility check scheduled)")
    }
    
    // MARK: - Window Management
    
    @objc func showPopup() {
        // 未登录状态不显示主界面
        guard authService.getToken() != nil else {
            print("⚡️ [AppDelegate] showPopup - not logged in, showing login window")
            showLoginWindow()
            return
        }
        
        print("⚡️ [AppDelegate] showPopup - start")
        if popupWindow == nil {
            print("⚡️ [AppDelegate] showPopup - creating PopupWindow")
            popupWindow = PopupWindow()
        }
        print("⚡️ [AppDelegate] showPopup - calling popupWindow.showPopup()")
        popupWindow?.showPopup()
        print("⚡️ [AppDelegate] showPopup - done")
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
            let loginView = LoginView { [weak self] in
                guard let self = self else { return }
                // 登录成功回调 - 使用 DispatchQueue 避免在闭包中直接操作窗口
                DispatchQueue.main.async {
                    print("⚡️ [AppDelegate] Login success callback - Step 1: starting app")
                    self.startApp()
                    
                    print("⚡️ [AppDelegate] Login success callback - Step 2: showing popup")
                    self.showPopup()
                    
                    print("⚡️ [AppDelegate] Login success callback - Step 3: scheduling login window close")
                    // 延迟关闭登录窗口，等待动画完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("⚡️ [AppDelegate] Login success callback - Step 4: closing login window")
                        self.loginWindow?.orderOut(nil)  // 先隐藏，不带动画
                        self.loginWindow?.close()
                        self.loginWindow = nil
                        print("⚡️ [AppDelegate] Login success callback - Step 5: done")
                    }
                }
            }
            
            loginWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 650),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            loginWindow?.isReleasedWhenClosed = false  // 防止关闭时自动释放
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
            
            // 确保窗口可以接收键盘事件
            modalWindow.isReleasedWhenClosed = false
            
            let hostingView = NSHostingView(rootView: settingsView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            modalWindow.contentView = hostingView
            
            self.settingsWindow = modalWindow
            
            // 先显示窗口并激活
            modalWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // 运行 modal
            NSApp.runModal(for: modalWindow)
            self.settingsWindow = nil
        }
    }
    
    @objc func showSearch() {
        // 如果已经有搜索窗口，直接激活它
        if let existingWindow = searchWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let searchView = SearchView { [weak self] item in
            // 选择项目回调
            self?.searchWindow?.close()
            self?.searchWindow = nil
            self?.copyToClipboard(item)
        }
        
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.borderless, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.center()
        panel.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: searchView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        panel.contentView = hostingView
        
        self.searchWindow = panel
        
        // 显示窗口并激活
        panel.makeKeyAndOrderFront(nil)
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
    
    // MARK: - Accessibility Permission
    
    private static let kDontShowAccessibilityPrompt = "dontShowAccessibilityPrompt"
    private static let kAccessibilityPromptCount = "accessibilityPromptCount"
    private static let kMaxAccessibilityPrompts = 2  // 最多提示2次
    
    private func checkAccessibilityPermission() {
        print("⚡️ [AppDelegate] checkAccessibilityPermission - checking AXIsProcessTrusted")
        let trusted = AXIsProcessTrusted()
        print("⚡️ [AppDelegate] checkAccessibilityPermission - trusted: \(trusted)")
        
        if trusted {
            // 已获得权限，重置提示计数
            UserDefaults.standard.set(0, forKey: AppDelegate.kAccessibilityPromptCount)
            UserDefaults.standard.set(false, forKey: AppDelegate.kDontShowAccessibilityPrompt)
            print("⚡️ [AppDelegate] checkAccessibilityPermission - already trusted, reset prompt count")
            return
        }
        
        // 检查用户是否选择了不再提示
        let dontShow = UserDefaults.standard.bool(forKey: AppDelegate.kDontShowAccessibilityPrompt)
        print("⚡️ [AppDelegate] checkAccessibilityPermission - dontShow: \(dontShow)")
        
        if dontShow {
            print("⚡️ [AppDelegate] checkAccessibilityPermission - user chose not to show")
            return
        }
        
        // 检查已提示次数
        let promptCount = UserDefaults.standard.integer(forKey: AppDelegate.kAccessibilityPromptCount)
        if promptCount >= AppDelegate.kMaxAccessibilityPrompts {
            print("⚡️ [AppDelegate] checkAccessibilityPermission - max prompts reached (\(promptCount))")
            return
        }
        
        print("⚡️ [AppDelegate] checkAccessibilityPermission - showing dialog (count: \(promptCount))")
        showAccessibilityPermissionDialog()
        
        // 增加提示计数
        UserDefaults.standard.set(promptCount + 1, forKey: AppDelegate.kAccessibilityPromptCount)
        print("⚡️ [AppDelegate] checkAccessibilityPermission - done")
    }
    
    private func showAccessibilityPermissionDialog() {
        print("⚡️ [AppDelegate] showAccessibilityPermissionDialog - creating alert")
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        Pastee 需要辅助功能权限才能实现以下功能：
        
        • 点击剪贴板项目后自动粘贴
        • 全局快捷键 (⌘⇧V)
        
        请在系统设置中启用 Pastee 的辅助功能权限。
        
        💡 如果已授权但仍看到此提示，请在辅助功能列表中删除 Pastee 后重新添加。
        """
        alert.alertStyle = .warning
        alert.icon = NSImage(systemSymbolName: "hand.raised.circle.fill", accessibilityDescription: "Permission")
        
        // 添加"不再提示"复选框
        let checkbox = NSButton(checkboxWithTitle: "不再提示", target: nil, action: nil)
        checkbox.state = .off
        alert.accessoryView = checkbox
        
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后再说")
        
        print("⚡️ [AppDelegate] showAccessibilityPermissionDialog - running modal")
        let response = alert.runModal()
        print("⚡️ [AppDelegate] showAccessibilityPermissionDialog - modal returned: \(response)")
        
        // 保存用户的"不再提示"选择
        if checkbox.state == .on {
            UserDefaults.standard.set(true, forKey: AppDelegate.kDontShowAccessibilityPrompt)
        }
        
        if response == .alertFirstButtonReturn {
            // 打开系统设置的辅助功能页面
            print("⚡️ [AppDelegate] showAccessibilityPermissionDialog - opening settings")
            openAccessibilitySettings()
        }
        print("⚡️ [AppDelegate] showAccessibilityPermissionDialog - done")
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
            print("⚡️ [OAuth] Invalid callback URL: \(event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue ?? "nil")")
            return
        }
        
        print("⚡️ [OAuth] Received callback with token")
        
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
    static let adjustWindowWidth = Notification.Name("adjustWindowWidth")
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

