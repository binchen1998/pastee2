//
//  Theme.swift
//  Pastee
//
//  颜色主题定义 - 支持暗色/亮色模式动态切换
//

import SwiftUI
import Combine

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            NotificationCenter.default.post(name: .themeChanged, object: nil)
        }
    }
    
    private init() {
        // 从 UserDefaults 读取，默认暗色模式
        self.isDarkMode = UserDefaults.standard.object(forKey: "isDarkMode") as? Bool ?? true
    }
    
    func toggle() {
        isDarkMode.toggle()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}

// MARK: - Theme Colors

struct Theme {
    // 动态获取当前主题颜色
    static var isDarkMode: Bool {
        ThemeManager.shared.isDarkMode
    }
    
    // 背景色
    static var background: Color {
        isDarkMode ? Color(hex: "#1E1E2E") : Color(hex: "#FFFFFF")
    }
    
    static var surface: Color {
        isDarkMode ? Color(hex: "#2A2A3C") : Color(hex: "#F5F5F5")
    }
    
    static var surfaceHover: Color {
        isDarkMode ? Color(hex: "#363650") : Color(hex: "#E8E8E8")
    }
    
    // 强调色
    static var accent: Color {
        isDarkMode ? Color(hex: "#89B4FA") : Color(hex: "#1976D2")
    }
    
    static var accentSecondary: Color {
        isDarkMode ? Color(hex: "#B4BEFE") : Color(hex: "#42A5F5")
    }
    
    // 文字颜色
    static var textPrimary: Color {
        isDarkMode ? Color(hex: "#CDD6F4") : Color(hex: "#212121")
    }
    
    static var textSecondary: Color {
        isDarkMode ? Color(hex: "#A6ADC8") : Color(hex: "#757575")
    }
    
    // 边框
    static var border: Color {
        isDarkMode ? Color(hex: "#45475A") : Color(hex: "#E0E0E0")
    }
    
    // 删除/危险色
    static var delete: Color {
        isDarkMode ? Color(hex: "#F38BA8") : Color(hex: "#E53935")
    }
    
    // 成功色
    static var success: Color {
        Color(hex: "#4CAF50")
    }
    
    // 警告色
    static var warning: Color {
        isDarkMode ? Color(hex: "#FAB387") : Color(hex: "#FF9800")
    }
    
    // 卡片背景
    static var cardBackground: Color {
        isDarkMode ? Color(hex: "#2A2A3C") : Color(hex: "#FFFFFF")
    }
    
    // 卡片边框
    static var cardBorder: Color {
        isDarkMode ? Color(hex: "#45475A") : Color(hex: "#E0E0E0")
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme Aware View Modifier

struct ThemeAware: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .id(themeManager.isDarkMode) // 强制刷新视图
    }
}

extension View {
    func themeAware() -> some View {
        modifier(ThemeAware())
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Theme.accentSecondary : Theme.accent)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Theme.surfaceHover : Theme.surface)
            )
    }
}

struct LinkButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundColor(configuration.isPressed ? Theme.accentSecondary : Theme.accent)
    }
}

struct DeleteButtonStyle: ButtonStyle {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Theme.delete.opacity(0.8) : Theme.delete)
            )
    }
}
