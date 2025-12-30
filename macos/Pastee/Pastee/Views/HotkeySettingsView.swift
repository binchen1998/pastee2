//
//  HotkeySettingsView.swift
//  Pastee
//
//  快捷键设置界面
//

import SwiftUI
import Carbon

struct HotkeySettingsView: View {
    @State private var selectedHotkey: String
    @State private var isRecording = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKeyCode: UInt16 = 0
    
    let onSave: (String) -> Void
    let onDismiss: () -> Void
    
    // macOS 风格的预设快捷键
    private let presets = [
        "Command + Shift + V",
        "Command + Shift + C",
        "Command + Option + V",
        "Control + Shift + V",
        "Control + Option + V"
    ]
    
    init(currentHotkey: String = "Command + Shift + V",
         onSave: @escaping (String) -> Void = { _ in },
         onDismiss: @escaping () -> Void = {}) {
        _selectedHotkey = State(initialValue: currentHotkey)
        self.onSave = onSave
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Text("⌨️ Global Hotkey Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("✕")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)
            
            Text("Click the box below and press your desired hotkey:")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 15)
            
            // 按键录制框
            HotkeyRecorderView(
                hotkey: $selectedHotkey,
                isRecording: $isRecording
            )
            .padding(.bottom, 20)
            
            Text("Or select a preset:")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 10)
            
            // 快捷键预设选项
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(presets.prefix(3), id: \.self) { preset in
                        HotkeyButton(
                            title: preset,
                            isSelected: selectedHotkey == preset,
                            action: { selectedHotkey = preset }
                        )
                    }
                }
                HStack(spacing: 8) {
                    ForEach(presets.suffix(2), id: \.self) { preset in
                        HotkeyButton(
                            title: preset,
                            isSelected: selectedHotkey == preset,
                            action: { selectedHotkey = preset }
                        )
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack {
                Spacer()
                
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(LinkButtonStyle())
                .padding(.trailing, 20)
                
                Button("Save") {
                    saveAndApply()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(25)
        .frame(width: 450, height: 320)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
    
    private func saveAndApply() {
        var settings = SettingsManager.shared.load()
        settings.hotkey = selectedHotkey
        SettingsManager.shared.save(settings)
        
        HotkeyService.shared.register(hotkey: selectedHotkey)
        
        onSave(selectedHotkey)
        onDismiss()
    }
}

// MARK: - HotkeyRecorderView

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: String
    @Binding var isRecording: Bool
    
    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onHotkeyRecorded = { newHotkey in
            hotkey = newHotkey
            isRecording = false
        }
        view.onRecordingStateChanged = { recording in
            isRecording = recording
        }
        return view
    }
    
    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.currentHotkey = hotkey
        nsView.needsDisplay = true
    }
}

// MARK: - HotkeyRecorderNSView

class HotkeyRecorderNSView: NSView {
    var currentHotkey: String = ""
    var isRecording = false
    var onHotkeyRecorded: ((String) -> Void)?
    var onRecordingStateChanged: ((Bool) -> Void)?
    
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    
    override var acceptsFirstResponder: Bool { true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        onRecordingStateChanged?(true)
        needsDisplay = true
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        
        let modifiers = event.modifierFlags
        let keyCode = event.keyCode
        
        // 需要至少一个修饰键
        let hasModifier = modifiers.contains(.command) || 
                          modifiers.contains(.control) || 
                          modifiers.contains(.option) ||
                          modifiers.contains(.shift)
        
        guard hasModifier else { return }
        
        // 构建快捷键字符串
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("Command") }
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        
        if let keyName = keyCodeToName(keyCode) {
            parts.append(keyName)
        }
        
        let hotkeyString = parts.joined(separator: " + ")
        
        isRecording = false
        onRecordingStateChanged?(false)
        onHotkeyRecorded?(hotkeyString)
        needsDisplay = true
    }
    
    override func flagsChanged(with event: NSEvent) {
        // 当修饰键改变时刷新显示
        if isRecording {
            needsDisplay = true
        }
    }
    
    private func keyCodeToName(_ keyCode: UInt16) -> String? {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape",
            123: "Left", 124: "Right", 125: "Down", 126: "Up"
        ]
        return keyMap[keyCode]
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(width: 400, height: 44)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bounds = self.bounds
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        
        // 背景
        if isRecording {
            NSColor(Theme.accent).withAlphaComponent(0.1).setFill()
        } else if isHovering {
            NSColor(Theme.surfaceHover).setFill()
        } else {
            NSColor(Theme.surface).setFill()
        }
        path.fill()
        
        // 边框
        if isRecording {
            NSColor(Theme.accent).setStroke()
            path.lineWidth = 2
        } else {
            NSColor(Theme.border).setStroke()
            path.lineWidth = 1
        }
        path.stroke()
        
        // 文字
        let displayText: String
        if isRecording {
            displayText = "Press your hotkey combination..."
        } else {
            displayText = displayHotkey(currentHotkey)
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: isRecording ? NSColor(Theme.accent) : NSColor(Theme.textPrimary)
        ]
        
        let textSize = displayText.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        displayText.draw(in: textRect, withAttributes: attributes)
    }
    
    private func displayHotkey(_ hotkey: String) -> String {
        return hotkey
            .replacingOccurrences(of: "Command", with: "⌘")
            .replacingOccurrences(of: "Control", with: "⌃")
            .replacingOccurrences(of: "Option", with: "⌥")
            .replacingOccurrences(of: "Shift", with: "⇧")
            .replacingOccurrences(of: " + ", with: " ")
    }
}

// MARK: - HotkeyButton

struct HotkeyButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Text(displayTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : Theme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Theme.accent : (isHovering ? Theme.surfaceHover : Theme.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var displayTitle: String {
        title
            .replacingOccurrences(of: "Command", with: "⌘")
            .replacingOccurrences(of: "Shift", with: "⇧")
            .replacingOccurrences(of: "Option", with: "⌥")
            .replacingOccurrences(of: "Control", with: "⌃")
            .replacingOccurrences(of: " + ", with: "")
    }
}

// MARK: - Preview

#Preview {
    HotkeySettingsView()
}
