//
//  PopupWindow.swift
//  Pastee
//
//  悬浮弹窗窗口 - 不抢占焦点的浮动面板
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - 边缘调整大小的方向
struct ResizeEdge: OptionSet {
    let rawValue: Int
    
    static let none   = ResizeEdge([])
    static let left   = ResizeEdge(rawValue: 1 << 0)
    static let right  = ResizeEdge(rawValue: 1 << 1)
    static let top    = ResizeEdge(rawValue: 1 << 2)
    static let bottom = ResizeEdge(rawValue: 1 << 3)
    
    static let topLeft: ResizeEdge = [.top, .left]
    static let topRight: ResizeEdge = [.top, .right]
    static let bottomLeft: ResizeEdge = [.bottom, .left]
    static let bottomRight: ResizeEdge = [.bottom, .right]
}

// 自定义HostingView：允许第一次点击直接传递到控件，透明背景
class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    private var trackingArea: NSTrackingArea?
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true  // 关键：接受第一次鼠标点击
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 确保背景透明
        self.layer?.backgroundColor = .clear
        // 设置鼠标跟踪区域
        setupTrackingArea()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }
    
    private func setupTrackingArea() {
        // 移除旧的跟踪区域
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }
        
        // 创建新的跟踪区域，覆盖整个视图
        // activeAlways 确保即使窗口不是 key window 也能接收事件
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: window,  // 事件发送给窗口处理
            userInfo: nil
        )
        
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }
}

class PopupWindow: NSPanel {
    private var contentHostingView: FirstClickHostingView<ClipboardPopupView>?
    private static let frameSaveKey = "PopupWindowFrame"
    
    // 边缘调整大小相关
    private let edgeThreshold: CGFloat = 6  // 边缘检测阈值（像素）
    private var currentResizeEdge: ResizeEdge = .none
    private var isResizing = false
    private var resizeStartFrame: NSRect = .zero
    private var resizeStartMouseLocation: NSPoint = .zero
    
    // 鼠标事件监控器，用于捕获鼠标移动事件
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    
    // 光标管理：跟踪是否已经 push 了自定义光标
    private var hasPushedCursor = false
    
    // 允许成为key窗口以接收键盘事件，但不成为主窗口
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    init() {
        // 恢复保存的窗口大小
        let savedFrame = Self.loadSavedFrame()
        let initialRect = savedFrame ?? NSRect(x: 0, y: 0, width: 520, height: 500)
        
        super.init(
            contentRect: initialRect,
            // 无边框、无标题栏的浮动面板，支持调整大小
            styleMask: [.borderless, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        
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
        
        // 监听窗口激活/取消激活通知，用于修复鼠标光标状态
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: self
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: self
        )
        
        // 设置本地鼠标事件监控器，确保即使焦点丢失后也能正确处理边缘检测
        setupLocalMouseMonitor()
    }
    
    private func setupLocalMouseMonitor() {
        // 移除旧的监控器
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        
        // 处理鼠标移动的通用逻辑
        let handleMouseMove: () -> Void = { [weak self] in
            guard let self = self, self.isVisible else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = self.frame
            
            // 检查鼠标是否在窗口范围内（包括边缘）
            let expandedFrame = windowFrame.insetBy(dx: -2, dy: -2)
            if expandedFrame.contains(mouseLocation) {
                let edge = self.detectEdge(at: mouseLocation)
                self.currentResizeEdge = edge
                self.updateCursor(for: edge)
            } else if !self.isResizing {
                // 鼠标移出窗口范围时，恢复默认光标
                self.currentResizeEdge = .none
                self.resetCursorToArrow()
            }
        }
        
        // 创建本地事件监控器（当应用是活动应用时）
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            handleMouseMove()
            return event
        }
        
        // 创建全局事件监控器（当应用不是活动应用时，用于处理 nonactivatingPanel 的情况）
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
            handleMouseMove()
        }
    }
    
    // MARK: - 边缘检测与调整大小
    
    /// 检测鼠标位置对应的边缘
    private func detectEdge(at point: NSPoint) -> ResizeEdge {
        let frame = self.frame
        let localPoint = NSPoint(x: point.x - frame.origin.x, y: point.y - frame.origin.y)
        
        var edge: ResizeEdge = .none
        
        // 检测左右边缘
        if localPoint.x <= edgeThreshold {
            edge.insert(.left)
        } else if localPoint.x >= frame.width - edgeThreshold {
            edge.insert(.right)
        }
        
        // 检测上下边缘
        if localPoint.y <= edgeThreshold {
            edge.insert(.bottom)
        } else if localPoint.y >= frame.height - edgeThreshold {
            edge.insert(.top)
        }
        
        return edge
    }
    
    /// 根据边缘设置光标
    private func updateCursor(for edge: ResizeEdge) {
        // 确定目标光标
        let targetCursor: NSCursor
        switch edge {
        case .left, .right:
            targetCursor = NSCursor.resizeLeftRight
        case .top, .bottom:
            targetCursor = NSCursor.resizeUpDown
        case .topLeft, .bottomRight:
            targetCursor = NSCursor.crosshair
        case .topRight, .bottomLeft:
            targetCursor = NSCursor.crosshair
        case .none:
            targetCursor = NSCursor.arrow
        default:
            // 组合边缘（角落）
            if edge.contains(.left) || edge.contains(.right) {
                if edge.contains(.top) || edge.contains(.bottom) {
                    targetCursor = NSCursor.crosshair
                } else {
                    targetCursor = NSCursor.resizeLeftRight
                }
            } else {
                targetCursor = NSCursor.resizeUpDown
            }
        }
        
        // 使用 push/pop 来强制更新光标
        if edge != .none {
            // 需要显示 resize 光标
            if hasPushedCursor {
                NSCursor.pop()
            }
            targetCursor.push()
            hasPushedCursor = true
        } else {
            // 恢复默认光标
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }
    
    /// 重置光标为箭头（确保正确 pop 之前 push 的光标）
    private func resetCursorToArrow() {
        if hasPushedCursor {
            NSCursor.pop()
            hasPushedCursor = false
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        let edge = detectEdge(at: mouseLocation)
        currentResizeEdge = edge
        updateCursor(for: edge)
        super.mouseMoved(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        let edge = detectEdge(at: mouseLocation)
        
        if edge != .none {
            // 开始调整大小
            isResizing = true
            currentResizeEdge = edge
            resizeStartFrame = self.frame
            resizeStartMouseLocation = mouseLocation
            updateCursor(for: edge)
        } else {
            super.mouseDown(with: event)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        if isResizing {
            let currentMouseLocation = NSEvent.mouseLocation
            let deltaX = currentMouseLocation.x - resizeStartMouseLocation.x
            let deltaY = currentMouseLocation.y - resizeStartMouseLocation.y
            
            var newFrame = resizeStartFrame
            
            // 根据边缘调整窗口
            if currentResizeEdge.contains(.left) {
                newFrame.origin.x = resizeStartFrame.origin.x + deltaX
                newFrame.size.width = resizeStartFrame.width - deltaX
            }
            if currentResizeEdge.contains(.right) {
                newFrame.size.width = resizeStartFrame.width + deltaX
            }
            if currentResizeEdge.contains(.bottom) {
                newFrame.origin.y = resizeStartFrame.origin.y + deltaY
                newFrame.size.height = resizeStartFrame.height - deltaY
            }
            if currentResizeEdge.contains(.top) {
                newFrame.size.height = resizeStartFrame.height + deltaY
            }
            
            // 应用最小/最大尺寸限制
            if newFrame.size.width < minSize.width {
                if currentResizeEdge.contains(.left) {
                    newFrame.origin.x = resizeStartFrame.maxX - minSize.width
                }
                newFrame.size.width = minSize.width
            }
            if newFrame.size.width > maxSize.width {
                if currentResizeEdge.contains(.left) {
                    newFrame.origin.x = resizeStartFrame.maxX - maxSize.width
                }
                newFrame.size.width = maxSize.width
            }
            if newFrame.size.height < minSize.height {
                if currentResizeEdge.contains(.bottom) {
                    newFrame.origin.y = resizeStartFrame.maxY - minSize.height
                }
                newFrame.size.height = minSize.height
            }
            if newFrame.size.height > maxSize.height {
                if currentResizeEdge.contains(.bottom) {
                    newFrame.origin.y = resizeStartFrame.maxY - maxSize.height
                }
                newFrame.size.height = maxSize.height
            }
            
            self.setFrame(newFrame, display: true)
        } else {
            super.mouseDragged(with: event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            currentResizeEdge = .none
            resetCursorToArrow()
            saveFrame()
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if !isResizing {
            resetCursorToArrow()
        }
        super.mouseExited(with: event)
    }
    
    // MARK: - 窗口焦点变化处理
    
    @objc private func windowDidBecomeKey(_ notification: Notification) {
        // 窗口重新获得焦点时，确保鼠标移动事件可以被接收
        self.acceptsMouseMovedEvents = true
        
        // 强制更新 contentView 的 tracking areas
        contentHostingView?.updateTrackingAreas()
        
        // 重置光标状态（系统在焦点切换时可能已经重置了光标栈）
        currentResizeEdge = .none
        hasPushedCursor = false  // 重置状态，因为系统可能已经清空了光标栈
    }
    
    @objc private func windowDidResignKey(_ notification: Notification) {
        // 窗口失去焦点时，重置光标状态
        // 系统会在焦点切换时自动处理光标，我们只需要重置我们的状态
        currentResizeEdge = .none
        hasPushedCursor = false
    }
    
    override func becomeKey() {
        super.becomeKey()
        // 确保鼠标移动事件可以被接收
        self.acceptsMouseMovedEvents = true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        // 移除鼠标事件监控器
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
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


