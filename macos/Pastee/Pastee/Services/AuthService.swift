//
//  AuthService.swift
//  Pastee
//
//  认证服务
//

import Foundation
import AppKit

class AuthService {
    static let shared = AuthService()
    
    private let baseURL = "https://api.pastee-app.com"
    
    private var pasteeDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pastee")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var tokenFile: URL { pasteeDir.appendingPathComponent("auth.token") }
    private var deviceIdFile: URL { pasteeDir.appendingPathComponent("device.id") }
    
    private var cachedUserInfo: UserInfo?
    
    private init() {}
    
    // MARK: - Token Management
    
    var isLoggedIn: Bool {
        getToken() != nil
    }
    
    func getToken() -> String? {
        try? String(contentsOf: tokenFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func saveToken(_ token: String) {
        try? token.write(to: tokenFile, atomically: true, encoding: .utf8)
    }
    
    func logout() {
        try? FileManager.default.removeItem(at: tokenFile)
        cachedUserInfo = nil
    }
    
    // MARK: - Device ID
    
    func getDeviceId() -> String {
        if let existingId = try? String(contentsOf: deviceIdFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
            return existingId
        }
        
        let newId = "macos-\(UUID().uuidString.lowercased())"
        try? newId.write(to: deviceIdFile, atomically: true, encoding: .utf8)
        return newId
    }
    
    // MARK: - Login
    
    func login(email: String, password: String) async throws -> AuthResult {
        let url = URL(string: "\(baseURL)/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "username=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return AuthResult(success: false, token: nil, email: nil, errorMessage: "Network error")
        }
        
        if httpResponse.statusCode == 200 {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            saveToken(loginResponse.accessToken)
            return AuthResult(success: true, token: loginResponse.accessToken, email: email, errorMessage: nil)
        } else if httpResponse.statusCode == 401 {
            return AuthResult(success: false, token: nil, email: nil, errorMessage: "Incorrect email or password")
        } else if httpResponse.statusCode == 403 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            if errorResponse?.detail == "email_not_verified" {
                return AuthResult(success: false, token: nil, email: email, errorMessage: "email_not_verified")
            }
            return AuthResult(success: false, token: nil, email: nil, errorMessage: "Access denied")
        } else {
            return AuthResult(success: false, token: nil, email: nil, errorMessage: "Login failed (code: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Register
    
    func register(email: String, password: String) async throws -> AuthResult {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return AuthResult(success: false, token: nil, email: nil, errorMessage: "Network error")
        }
        
        if httpResponse.statusCode == 200 {
            return AuthResult(success: true, token: nil, email: email, errorMessage: nil)
        } else if httpResponse.statusCode == 400 {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            return AuthResult(success: false, token: nil, email: nil, errorMessage: errorResponse?.detail ?? "Registration failed")
        } else {
            return AuthResult(success: false, token: nil, email: nil, errorMessage: "Registration failed (code: \(httpResponse.statusCode))")
        }
    }
    
    // MARK: - Email Verification
    
    func verifyEmail(email: String, code: String) async throws -> AuthResult {
        let url = URL(string: "\(baseURL)/auth/verify-email")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "verification_code": code])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return AuthResult(success: false, token: nil, email: nil, errorMessage: "Network error")
        }
        
        if httpResponse.statusCode == 200 {
            // 验证成功后自动登录（如果返回了token）
            if let loginResponse = try? JSONDecoder().decode(LoginResponse.self, from: data) {
                saveToken(loginResponse.accessToken)
                return AuthResult(success: true, token: loginResponse.accessToken, email: email, errorMessage: nil)
            }
            return AuthResult(success: true, token: nil, email: email, errorMessage: nil)
        } else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            return AuthResult(success: false, token: nil, email: nil, errorMessage: errorResponse?.detail ?? "Verification failed")
        }
    }
    
    func resendVerificationCode(email: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/auth/resend-verification")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - User Info
    
    func getUserInfo() async throws -> UserInfo? {
        guard let token = getToken() else {
            print("⚡️ [Auth] getUserInfo: No token available")
            return nil
        }
        
        let url = URL(string: "\(baseURL)/auth/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("⚡️ [Auth] getUserInfo: Invalid response")
            return nil
        }
        
        print("⚡️ [Auth] getUserInfo: Status \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            logout()
            return nil
        }
        
        guard httpResponse.statusCode == 200 else {
            print("⚡️ [Auth] getUserInfo: Failed with status \(httpResponse.statusCode)")
            return nil
        }
        
        // 打印原始响应数据
        if let jsonString = String(data: data, encoding: .utf8) {
            print("⚡️ [Auth] getUserInfo response: \(jsonString)")
        }
        
        do {
            let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
            cachedUserInfo = userInfo
            print("⚡️ [Auth] getUserInfo: Success - email: \(userInfo.email)")
            return userInfo
        } catch {
            print("⚡️ [Auth] getUserInfo decode error: \(error)")
            return nil
        }
    }
    
    func getCachedUserInfo() -> UserInfo? {
        cachedUserInfo
    }
    
    func isAdmin() -> Bool {
        cachedUserInfo?.email.lowercased() == "admin@pastee.im"
    }
    
    // MARK: - Google OAuth
    
    func startGoogleOAuth() {
        let redirectUri = "pastee://oauth/callback"
        let url = URL(string: "\(baseURL)/auth/oauth/google/authorize?redirect_uri=\(redirectUri)")!
        NSWorkspace.shared.open(url)
    }
}

