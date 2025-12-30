//
//  HotkeySettingsView.swift
//  Pastee
//
//  快捷键设置界面
//

import SwiftUI

struct HotkeySettingsView: View {
    @State private var selectedHotkey: String
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
            
            Text("Select a hotkey to show/hide Pastee window:")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 20)
            
            // 快捷键选项
            VStack(alignment: .leading, spacing: 10) {
                // 第一行
                HStack(spacing: 10) {
                    ForEach(presets.prefix(3), id: \.self) { preset in
                        HotkeyButton(
                            title: preset,
                            isSelected: selectedHotkey == preset,
                            action: { selectedHotkey = preset }
                        )
                    }
                }
                // 第二行
                HStack(spacing: 10) {
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
        .frame(width: 420, height: 280)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
    
    private func saveAndApply() {
        // 保存设置
        var settings = SettingsManager.shared.load()
        settings.hotkey = selectedHotkey
        SettingsManager.shared.save(settings)
        
        // 重新注册快捷键
        HotkeyService.shared.register(hotkey: selectedHotkey)
        
        // 回调通知
        onSave(selectedHotkey)
        onDismiss()
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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
    
    // 使用符号显示快捷键
    private var displayTitle: String {
        title
            .replacingOccurrences(of: "Command", with: "⌘")
            .replacingOccurrences(of: "Shift", with: "⇧")
            .replacingOccurrences(of: "Option", with: "⌥")
            .replacingOccurrences(of: "Control", with: "⌃")
            .replacingOccurrences(of: " + ", with: "")
    }
}

// MARK: - Button Styles

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(configuration.isPressed ? Theme.textSecondary : Theme.accent)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Theme.accent.opacity(0.8) : Theme.accent)
            )
    }
}

// MARK: - Preview

#Preview {
    HotkeySettingsView()
}
