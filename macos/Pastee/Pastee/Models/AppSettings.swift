//
//  AppSettings.swift
//  Pastee
//
//  应用设置数据模型
//

import Foundation

struct AppSettings: Codable {
    var hotkey: String = "Command + Shift + V"
    var hideAfterPaste: Bool = true
    var launchAtLogin: Bool = false
    var darkMode: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case hotkey
        case hideAfterPaste = "hide_after_paste"
        case launchAtLogin = "launch_at_login"
        case darkMode = "dark_mode"
    }
}

// MARK: - 认证相关模型

struct AuthResult {
    let success: Bool
    let token: String?
    let email: String?
    let errorMessage: String?
}

struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct RegisterResponse: Codable {
    let message: String
    let email: String
}

struct UserInfo: Codable {
    let id: Int
    let email: String
    let storageUsed: Int?
    let storageLimit: Int?
    let isVerified: Bool?
    let isActive: Bool?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case storageUsed = "storage_used"
        case storageLimit = "storage_limit"
        case isVerified = "is_verified"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct VersionCheckResponse: Codable {
    let updateAvailable: Bool
    let latestVersion: String?
    let isMandatory: Bool?
    let releaseNotes: String?
    let downloadUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case updateAvailable = "update_available"
        case latestVersion = "latest_version"
        case isMandatory = "is_mandatory"
        case releaseNotes = "release_notes"
        case downloadUrl = "download_url"
    }
    
    // 便捷属性，提供默认值
    var version: String { latestVersion ?? "1.0.0" }
    var mandatory: Bool { isMandatory ?? false }
}

struct ErrorResponse: Codable {
    let detail: String
}

