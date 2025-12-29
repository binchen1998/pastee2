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
    @State private var showHotkeySettings = false
    @State private var showAdminPanel = false
    @State private var isAdmin = false
    
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
                        
                        // Admin Panel (仅管理员可见)
                        if isAdmin {
                            Button(action: { showAdminPanel = true }) {
                                HStack {
                                    HStack(spacing: 12) {
                                        Text("🛠")
                                            .font(.system(size: 20))
                                        
                                        VStack(alignment: .leading) {
                                            Text("Admin Panel")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(Theme.accent)
                                            Text("Manage users, versions, and settings")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("→")
                                        .font(.system(size: 18))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding(15)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Theme.surface)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 15)
                        }
                        
                        Divider()
                            .background(Theme.border)
                            .padding(.vertical, 25)
                        
                        // Shortcut Settings
                        settingRow(
                            icon: "⌨",
                            iconColor: Color(hex: "#2ecc71"),
                            title: "Shortcut Settings",
                            subtitle: "Configure global keyboard shortcuts",
                            action: { showHotkeySettings = true }
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
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pastee")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textSecondary)
                                    Text("Version \(version)")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                }
                                
                                Spacer()
                                
                                Button(action: { checkUpdates() }) {
                                    HStack(spacing: 6) {
                                        Text("📥")
                                            .font(.system(size: 12))
                                        Text("Check Updates")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(Theme.accent)
                                }
                                .buttonStyle(.plain)
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
        .sheet(isPresented: $showHotkeySettings) {
            HotkeySettingsView()
        }
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
        
        deviceId = AuthService.shared.getDeviceId()
        version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // 加载用户信息
        Task {
            if let userInfo = try? await AuthService.shared.getUserInfo() {
                await MainActor.run {
                    email = userInfo.email
                    isAdmin = userInfo.email.lowercased() == "admin@pastee.im"
                }
            }
        }
    }
    
    private func saveSettings() {
        var settings = SettingsManager.shared.load()
        settings.launchAtLogin = autoStart
        settings.hideAfterPaste = hideAfterPaste
        SettingsManager.shared.save(settings)
    }
    
    private func checkUpdates() {
        Task {
            await UpdateService.shared.checkForUpdate()
        }
    }
    
    private func openSupportEmail() {
        if let url = URL(string: "mailto:binary.chen@gmail.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

// MARK: - Preview

#Preview {
    SettingsView(onLogout: {})
}

