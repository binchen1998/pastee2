//
//  PopupWindow.swift
//  Pastee
//
//  悬浮弹窗窗口 - 不抢占焦点的浮动面板
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

// 自定义HostingView：允许第一次点击直接传递到控件，透明背景
class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true  // 关键：接受第一次鼠标点击
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 确保背景透明
        self.layer?.backgroundColor = .clear
    }
}

class PopupWindow: NSPanel {
    private var contentHostingView: FirstClickHostingView<ClipboardPopupView>?
    private static let frameSaveKey = "PopupWindowFrame"
    
    // 允许成为key窗口以接收键盘事件，但不成为主窗口
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    init() {
        // 恢复保存的窗口大小
        let savedFrame = Self.loadSavedFrame()
        let initialRect = savedFrame ?? NSRect(x: 0, y: 0, width: 520, height: 500)
        
        super.init(
            contentRect: initialRect,
            // 使用 titled + resizable 获得系统原生的 resize 支持和光标处理
            // 不使用 fullSizeContentView，让系统保留边框区域处理光标
            styleMask: [.titled, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
        // 隐藏标题栏但保留系统的边框和 resize 功能
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        // 隐藏标题栏按钮（关闭、最小化、最大化）
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // 关键设置：浮动窗口，不激活应用
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.minSize = NSSize(width: 380, height: 300)
        self.maxSize = NSSize(width: 800, height: 900)
        
        // 关键：允许在非活动状态下接收鼠标事件
        self.acceptsMouseMovedEvents = true
        self.hidesOnDeactivate = false
        
        // ⭐ 关键：只在需要时才成为key窗口，允许第一次点击直接传递
        self.becomesKeyOnlyIfNeeded = true
        
        // 设置集合行为：不占用空间，可在所有空间显示
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        
        // 如果没有保存的位置，设置到屏幕右下角
        if savedFrame == nil {
            positionNearCorner()
        }
        
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
        
        // 监听窗口宽度调整通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAdjustWindowWidth),
            name: .adjustWindowWidth,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePasteNotification() {
        print("⚡️ [PopupWindow] Received paste notification!")
        pasteToFocusedApp()
    }
    
    @objc private func handleAdjustWindowWidth(_ notification: Notification) {
        guard let widthDelta = notification.object as? CGFloat else { return }
        
        var newFrame = self.frame
        newFrame.size.width += widthDelta
        
        // 确保不小于最小宽度
        let minWidth = self.minSize.width
        if newFrame.size.width < minWidth {
            newFrame.size.width = minWidth
        }
        
        // 使用动画调整窗口大小
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
        
        print("⚡️ [PopupWindow] Adjusted window width by \(widthDelta), new width: \(newFrame.size.width)")
    }
    
    private func positionNearCorner() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = self.frame.size
        
        let x = screenFrame.maxX - windowSize.width - 20
        let y = screenFrame.minY + 20
        
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // MARK: - 窗口大小保存/恢复
    
    private static func loadSavedFrame() -> NSRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: frameSaveKey),
              let x = dict["x"] as? CGFloat,
              let y = dict["y"] as? CGFloat,
              let width = dict["width"] as? CGFloat,
              let height = dict["height"] as? CGFloat else {
            return nil
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    private func saveFrame() {
        let frame = self.frame
        let dict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(dict, forKey: Self.frameSaveKey)
    }
    
    func showPopup() {
        // 关键：不使用 makeKeyAndOrderFront，不调用 NSApp.activate
        // 使用 orderFrontRegardless 显示窗口但不抢占焦点
        self.orderFrontRegardless()
        
        // 确保鼠标移动事件可以被接收
        self.acceptsMouseMovedEvents = true
        
        // 强制更新 tracking areas 以确保边缘调整大小功能正常
        contentHostingView?.updateTrackingAreas()
    }
    
    func hidePopup() {
        saveFrame()
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


