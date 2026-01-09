//
//  SettingsView.swift
//  Pastee
//
//  设置界面
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var email = ""
    @State private var deviceId = ""
    @State private var version = "1.0.0"
    @State private var autoStart = false
    @State private var hideAfterPaste = true
    @State private var currentHotkey = "Command + Shift + V"
    @State private var isDarkMode = true
    @State private var alwaysOnTop = true
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var currentHotkeyDescription: String {
        "Current: \(currentHotkey)"
    }
    
    let onLogout: () -> Void
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 头部
                HStack {
                    Text("Settings")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { closeWindow() }) {
                        Text("✕")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 25)
                .padding(.top, 20)
                .padding(.bottom, 15)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Account Section
                        sectionHeader("Account")
                        
                        infoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Text(email)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        
                        Divider()
                            .background(Theme.border)
                            .padding(.vertical, 25)
                        
                        // Shortcut Settings
                        settingRow(
                            icon: "⌨",
                            iconColor: Color(hex: "#2ecc71"),
                            title: "Shortcut Settings",
                            subtitle: currentHotkeyDescription,
                            action: { openHotkeySettings() }
                        )
                        
                        // Launch on Start
                        settingToggleRow(
                            icon: "⏻",
                            iconColor: Color(hex: "#27ae60"),
                            title: "Launch on Start",
                            subtitle: "Start Pastee automatically when system boots",
                            isOn: $autoStart
                        )
                        .onChange(of: autoStart) { newValue in
                            SettingsManager.shared.setLaunchAtLogin(newValue)
                            saveSettings()
                        }
                        
                        // Hide After Paste
                        settingToggleRow(
                            icon: "👁",
                            iconColor: Color(hex: "#9b59b6"),
                            title: "Hide After Paste",
                            subtitle: "Automatically hide window after pasting",
                            isOn: $hideAfterPaste
                        )
                        .onChange(of: hideAfterPaste) { newValue in
                            saveSettings()
                        }
                        
                        // Always On Top
                        settingToggleRow(
                            icon: "📌",
                            iconColor: Color(hex: "#2980b9"),
                            title: "Always On Top",
                            subtitle: "Keep Pastee above other windows",
                            isOn: $alwaysOnTop
                        )
                        .onChange(of: alwaysOnTop) { _ in
                            saveSettings(notifyAlwaysOnTopChange: true)
                        }
                        
                        // Dark Mode
                        settingToggleRow(
                            icon: "🌙",
                            iconColor: Color(hex: "#3498db"),
                            title: "Dark Mode",
                            subtitle: "Switch between dark and light theme",
                            isOn: $isDarkMode
                        )
                        .onChange(of: isDarkMode) { newValue in
                            themeManager.isDarkMode = newValue
                        }
                        
                        // Clear Cache
                        settingRow(
                            icon: "🗑",
                            iconColor: Theme.delete,
                            title: "Clear Cache",
                            subtitle: "Clear all cached data and images",
                            action: {
                                SettingsManager.shared.clearCache()
                            }
                        )
                        
                        Divider()
                            .background(Theme.border)
                            .padding(.vertical, 20)
                        
                        // Device Info
                        sectionHeader("Device Information")
                        
                        infoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Device ID")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Text(deviceId)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.bottom, 4)
                                Text("Unique device identifier, generated on first launch.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        
                        Divider()
                            .background(Theme.border)
                            .padding(.vertical, 25)
                        
                        // About
                        sectionHeader("About")
                        
                        infoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pastee")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Text("Version \(version)")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        
                        // Support
                        sectionHeader("Support")
                            .padding(.top, 20)
                        
                        infoCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                                Button(action: { openSupportEmail() }) {
                                    Text("binary.chen@gmail.com")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Logout Button
                        Button(action: onLogout) {
                            Text("Logout")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Theme.delete)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 40)
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 25)
                }
            }
        }
        .frame(width: 500, height: 650)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
        .onAppear {
            loadSettings()
        }
        .id(themeManager.isDarkMode) // 强制刷新视图以响应主题变化
    }
    
    // MARK: - Components
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundColor(Theme.textSecondary)
            .padding(.bottom, 10)
    }
    
    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surface)
            )
    }
    
    private func settingRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 0) {
                Text(icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func settingToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: Theme.success))
        }
        .padding(.vertical, 15)
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        let settings = SettingsManager.shared.load()
        autoStart = settings.launchAtLogin
        hideAfterPaste = settings.hideAfterPaste
        currentHotkey = settings.hotkey
        isDarkMode = themeManager.isDarkMode
        alwaysOnTop = settings.alwaysOnTop
        
        deviceId = AuthService.shared.getDeviceId()
        version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // 直接从本地获取 email（登录时已保存）
        if let savedEmail = AuthService.shared.getSavedEmail() {
            email = savedEmail
            print("⚡️ [Settings] Using saved email: \(savedEmail)")
        }
    }
    
    private func openHotkeySettings() {
        // 先关闭 Settings 窗口
        NSApp.stopModal()
        
        // 使用 DispatchQueue 确保 Settings 窗口已关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            // 关闭当前窗口
            NSApp.keyWindow?.close()
            
            // 保存对 hotkey 窗口的引用
            var hotkeyWindow: NSPanel?
            
            let hotkeyView = HotkeySettingsView(
                currentHotkey: currentHotkey,
                onSave: { newHotkey in
                    self.currentHotkey = newHotkey
                },
                onDismiss: {
                    NSApp.stopModal()
                    hotkeyWindow?.close()
                }
            )
            
            // 使用自定义 Panel 类让窗口可以接收键盘输入
            let panel = KeyablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
                styleMask: [.borderless, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.level = .modalPanel
            panel.center()
            panel.isReleasedWhenClosed = false
            
            let hostingView = NSHostingView(rootView: hotkeyView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            panel.contentView = hostingView
            
            hotkeyWindow = panel
            
            // 显示并激活
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            // 运行 modal
            NSApp.runModal(for: panel)
        }
    }
    
    private func saveSettings(notifyAlwaysOnTopChange: Bool = false) {
        var settings = SettingsManager.shared.load()
        settings.launchAtLogin = autoStart
        settings.hideAfterPaste = hideAfterPaste
        settings.alwaysOnTop = alwaysOnTop
        SettingsManager.shared.save(settings)
        
        if notifyAlwaysOnTopChange {
            NotificationCenter.default.post(name: .alwaysOnTopChanged, object: alwaysOnTop)
        }
    }
    
    private func openSupportEmail() {
        if let url = URL(string: "mailto:binary.chen@gmail.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func closeWindow() {
        // 停止 modal 并关闭窗口
        NSApp.stopModal()
        if let window = NSApp.windows.first(where: { $0.contentView is NSHostingView<SettingsView> }) {
            window.close()
        } else {
            NSApp.keyWindow?.close()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView(onLogout: {})
}

