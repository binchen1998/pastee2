//
//  LoginViewModel.swift
//  Pastee
//
//  登录界面ViewModel
//

import Foundation
import SwiftUI
import Combine

enum LoginViewState {
    case login
    case register
    case verifyEmail
}

@MainActor
class LoginViewModel: ObservableObject {
    @Published var viewState: LoginViewState = .login
    @Published var email = ""
    @Published var password = ""
    @Published var verificationCode = ""
    @Published var errorMessage = ""
    @Published var successMessage = ""
    @Published var isBusy = false
    @Published var isWaitingForOAuth = false
    
    private var cancellables = Set<AnyCancellable>()
    var onLoginSuccess: (() -> Void)?
    
    var isLoginView: Bool { viewState == .login }
    var isRegisterView: Bool { viewState == .register }
    var isVerifyEmailView: Bool { viewState == .verifyEmail }
    
    init() {
        // 监听OAuth回调
        NotificationCenter.default.publisher(for: .oauthLoginCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isWaitingForOAuth = false
                self?.onLoginSuccess?()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation
    
    func switchToLogin() {
        viewState = .login
        clearMessages()
    }
    
    func switchToRegister() {
        viewState = .register
        clearMessages()
    }
    
    func switchToVerifyEmail() {
        viewState = .verifyEmail
        clearMessages()
    }
    
    func backToLogin() {
        viewState = .login
        password = ""
        verificationCode = ""
        clearMessages()
    }
    
    private func clearMessages() {
        errorMessage = ""
        successMessage = ""
    }
    
    // MARK: - Login
    
    func login() async {
        guard validateLoginInput() else { return }
        
        isBusy = true
        clearMessages()
        
        do {
            let result = try await AuthService.shared.login(email: email, password: password)
            
            if result.success {
                onLoginSuccess?()
            } else if result.errorMessage == "email_not_verified" {
                switchToVerifyEmail()
            } else {
                errorMessage = result.errorMessage ?? "Login failed"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        
        isBusy = false
    }
    
    private func validateLoginInput() -> Bool {
        if email.isEmpty {
            errorMessage = "Please enter your email"
            return false
        }
        if password.isEmpty {
            errorMessage = "Please enter your password"
            return false
        }
        return true
    }
    
    // MARK: - Register
    
    func register() async {
        guard validateRegisterInput() else { return }
        
        isBusy = true
        clearMessages()
        
        do {
            let result = try await AuthService.shared.register(email: email, password: password)
            
            if result.success {
                successMessage = "Registration successful! Please check your email for verification code."
                switchToVerifyEmail()
            } else {
                errorMessage = result.errorMessage ?? "Registration failed"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        
        isBusy = false
    }
    
    private func validateRegisterInput() -> Bool {
        if email.isEmpty {
            errorMessage = "Please enter your email"
            return false
        }
        if !email.contains("@") {
            errorMessage = "Please enter a valid email"
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters"
            return false
        }
        return true
    }
    
    // MARK: - Email Verification
    
    func verifyEmail() async {
        guard !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isBusy = true
        clearMessages()
        
        do {
            let result = try await AuthService.shared.verifyEmail(email: email, code: verificationCode)
            
            if result.success {
                if result.token != nil {
                    // 自动登录成功
                    onLoginSuccess?()
                } else {
                    successMessage = "Email verified successfully! Please login."
                    switchToLogin()
                }
            } else {
                errorMessage = result.errorMessage ?? "Verification failed"
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        
        isBusy = false
    }
    
    func resendCode() async {
        isBusy = true
        clearMessages()
        
        do {
            let success = try await AuthService.shared.resendVerificationCode(email: email)
            
            if success {
                successMessage = "Verification code sent! Please check your email."
            } else {
                errorMessage = "Failed to resend code. Please try again."
            }
        } catch {
            errorMessage = "Network error: \(error.localizedDescription)"
        }
        
        isBusy = false
    }
    
    // MARK: - Google OAuth
    
    func startGoogleLogin() {
        isWaitingForOAuth = true
        AuthService.shared.startGoogleOAuth()
    }
}

