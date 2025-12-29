//
//  PopupWindow.swift
//  Pastee
//
//  悬浮弹窗窗口 - 不抢占焦点的浮动面板
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

// 自定义HostingView：允许第一次点击直接传递到控件
class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true  // 关键：接受第一次鼠标点击
    }
}

class PopupWindow: NSPanel {
    private var contentHostingView: FirstClickHostingView<ClipboardPopupView>?
    
    // 允许成为key窗口以接收键盘事件，但不成为主窗口
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        // 关键设置：浮动窗口，不激活应用
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.minSize = NSSize(width: 380, height: 300)
        
        // 关键：允许在非活动状态下接收鼠标事件
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        
        // ⭐ 关键：只在需要时才成为key窗口，允许第一次点击直接传递
        self.becomesKeyOnlyIfNeeded = true
        
        // 设置集合行为：不占用空间，可在所有空间显示
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        // 设置位置到屏幕右下角
        positionNearCorner()
        
        let popupView = ClipboardPopupView { [weak self] in
            self?.hidePopup()
        }
        
        contentHostingView = FirstClickHostingView(rootView: popupView)
        self.contentView = contentHostingView
        
        // 监听粘贴通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePasteNotification),
            name: .pasteToFocusedApp,
            object: nil
        )
        print("⚡️ [PopupWindow] Notification observer registered for pasteToFocusedApp")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePasteNotification() {
        print("⚡️ [PopupWindow] Received paste notification!")
        pasteToFocusedApp()
    }
    
    private func positionNearCorner() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = self.frame.size
        
        let x = screenFrame.maxX - windowSize.width - 20
        let y = screenFrame.minY + 20
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    func showPopup() {
        positionNearCorner()
        // 关键：不使用 makeKeyAndOrderFront，不调用 NSApp.activate
        // 使用 orderFrontRegardless 显示窗口但不抢占焦点
        self.orderFrontRegardless()
    }
    
    func hidePopup() {
        self.orderOut(nil)
    }
    
    /// 复制内容到剪贴板后，模拟 Cmd+V 粘贴到之前的焦点应用
    func pasteToFocusedApp() {
        print("⚡️ [PopupWindow] pasteToFocusedApp called")
        
        // 先隐藏窗口
        hidePopup()
        
        // 检查辅助功能权限
        let trusted = AXIsProcessTrusted()
        print("⚡️ [PopupWindow] Accessibility trusted: \(trusted)")
        
        if !trusted {
            // 请求辅助功能权限（会弹出系统对话框）
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            print("⚡️ [PopupWindow] ⚠️ 需要在「系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能」中启用 Pastee")
            return
        }
        
        // 延迟确保窗口隐藏后焦点回到原应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            print("⚡️ [PopupWindow] Executing simulatePaste")
            self.simulatePaste()
        }
    }
    
    private func simulatePaste() {
        // 模拟 Cmd+V 按键
        let source = CGEventSource(stateID: .hidSystemState)
        
        // 按下 Cmd+V
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cgSessionEventTap)
            print("[PopupWindow] Cmd+V keyDown posted to session")
        } else {
            print("[PopupWindow] Failed to create keyDown event - check Accessibility permissions!")
        }
        
        // 短暂延迟后释放
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) {
                keyUp.flags = .maskCommand
                keyUp.post(tap: .cgSessionEventTap)
                print("[PopupWindow] Cmd+V keyUp posted to session")
            }
        }
    }
}

