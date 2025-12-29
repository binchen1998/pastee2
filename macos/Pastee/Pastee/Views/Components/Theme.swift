//
//  Theme.swift
//  Pastee
//
//  颜色主题定义 (Catppuccin Mocha)
//

import SwiftUI

struct Theme {
    // 背景色
    static let background = Color(hex: "#1E1E2E")
    static let surface = Color(hex: "#2A2A3C")
    static let surfaceHover = Color(hex: "#363650")
    
    // 强调色
    static let accent = Color(hex: "#89B4FA")
    static let accentSecondary = Color(hex: "#B4BEFE")
    
    // 文字颜色
    static let textPrimary = Color(hex: "#CDD6F4")
    static let textSecondary = Color(hex: "#A6ADC8")
    
    // 边框
    static let border = Color(hex: "#45475A")
    
    // 删除/危险色
    static let delete = Color(hex: "#F38BA8")
    
    // 成功色
    static let success = Color(hex: "#4CAF50")
    
    // 警告色
    static let warning = Color(hex: "#FAB387")
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

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundColor(configuration.isPressed ? Theme.accentSecondary : Theme.accent)
    }
}

struct DeleteButtonStyle: ButtonStyle {
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

