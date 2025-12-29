//
//  HotkeySettingsView.swift
//  Pastee
//
//  快捷键设置界面
//

import SwiftUI

struct HotkeySettingsView: View {
    @State private var selectedHotkey: String
    let onDismiss: () -> Void
    
    private let presets = [
        "Command + Shift + V",
        "Ctrl + Shift + V",
        "Ctrl + Shift + C",
        "Ctrl + Alt + V",
        "Ctrl + Alt + C"
    ]
    
    init(onDismiss: @escaping () -> Void = {}) {
        let settings = SettingsManager.shared.load()
        _selectedHotkey = State(initialValue: settings.hotkey)
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            Text("Global Hotkey Settings")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .padding(.bottom, 10)
            
            Text("Select a hotkey to show/hide Pastee window:")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 20)
            
            // 快捷键选项 - 使用 VStack + HStack 兼容 macOS 12
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
                    onDismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(30)
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
        var settings = SettingsManager.shared.load()
        settings.hotkey = selectedHotkey
        SettingsManager.shared.save(settings)
        
        // 重新注册快捷键
        HotkeyService.shared.register(hotkey: selectedHotkey)
    }
}

// MARK: - HotkeyButton

struct HotkeyButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? Theme.background : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Theme.accent : Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HotkeySettingsView()
}

