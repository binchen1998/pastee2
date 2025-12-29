//
//  LoginView.swift
//  Pastee
//
//  登录界面
//

import SwiftUI
import AppKit

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    let onLoginSuccess: () -> Void
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: { NSApp.terminate(nil) }) {
                        Text("✕")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 15)
                    .padding(.trailing, 15)
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Logo
                        Text("Pastee")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.accent)
                        
                        Text("The best clipboard manager")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.top, 10)
                            .padding(.bottom, 40)
                        
                        // 视图切换
                        if viewModel.isLoginView {
                            loginContent
                        } else if viewModel.isRegisterView {
                            registerContent
                        } else if viewModel.isVerifyEmailView {
                            verifyEmailContent
                        }
                        
                        // 社交登录
                        if viewModel.isLoginView || viewModel.isRegisterView {
                            socialLoginSection
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
        .frame(width: 450, height: 650)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .onAppear {
            viewModel.onLoginSuccess = onLoginSuccess
        }
    }
    
    // MARK: - Login Content
    
    private var loginContent: some View {
        VStack(spacing: 0) {
            // 标签页
            HStack(spacing: 0) {
                tabButton(title: "Login", isSelected: true) {}
                tabButton(title: "Register", isSelected: false) {
                    viewModel.switchToRegister()
                }
            }
            .padding(.bottom, 24)
            
            // 消息
            messageView
            
            // Email
            inputField(placeholder: "Email", text: $viewModel.email)
                .padding(.bottom, 16)
            
            // Password
            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(CustomTextFieldStyle())
                .padding(.bottom, 16)
            
            // 登录按钮
            Button(action: {
                Task { await viewModel.login() }
            }) {
                Text("Login")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
            .disabled(viewModel.isBusy)
            
            if viewModel.isBusy {
                Text("Signing in...")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Register Content
    
    private var registerContent: some View {
        VStack(spacing: 0) {
            // 标签页
            HStack(spacing: 0) {
                tabButton(title: "Login", isSelected: false) {
                    viewModel.switchToLogin()
                }
                tabButton(title: "Register", isSelected: true) {}
            }
            .padding(.bottom, 24)
            
            // 消息
            messageView
            
            // Email
            inputField(placeholder: "Email", text: $viewModel.email)
                .padding(.bottom, 16)
            
            // Password
            SecureField("Password (min 6 characters)", text: $viewModel.password)
                .textFieldStyle(CustomTextFieldStyle())
                .padding(.bottom, 8)
            
            Text("Password must be at least 6 characters")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            
            // 注册按钮
            Button(action: {
                Task { await viewModel.register() }
            }) {
                Text("Create Account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
            .disabled(viewModel.isBusy)
            
            if viewModel.isBusy {
                Text("Creating account...")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 12)
            }
            
            Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
        }
    }
    
    // MARK: - Verify Email Content
    
    private var verifyEmailContent: some View {
        VStack(spacing: 0) {
            // 返回按钮
            Button(action: { viewModel.backToLogin() }) {
                HStack(spacing: 8) {
                    Text("←")
                    Text("Back to Login")
                }
                .foregroundColor(Theme.accent)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 20)
            
            // 标题
            Text("Verify Your Email")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .padding(.bottom, 8)
            
            VStack(spacing: 4) {
                Text("We sent a verification code to")
                    .foregroundColor(Theme.textSecondary)
                Text(viewModel.email)
                    .foregroundColor(Theme.accent)
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 24)
            
            // 消息
            messageView
            
            // 验证码输入
            TextField("Enter verification code", text: $viewModel.verificationCode)
                .textFieldStyle(CustomTextFieldStyle())
                .font(.system(size: 20))
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
            
            // 验证按钮
            Button(action: {
                Task { await viewModel.verifyEmail() }
            }) {
                Text("Verify Email")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
            .disabled(viewModel.isBusy)
            
            if viewModel.isBusy {
                Text("Verifying...")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 12)
            }
            
            // 重发验证码
            HStack {
                Text("Didn't receive the code?")
                    .foregroundColor(Theme.textSecondary)
                Button("Resend") {
                    Task { await viewModel.resendCode() }
                }
                .buttonStyle(LinkButtonStyle())
            }
            .font(.system(size: 14))
            .padding(.top, 24)
        }
    }
    
    // MARK: - Social Login
    
    private var socialLoginSection: some View {
        VStack(spacing: 0) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
                
                Text("or continue with")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 15)
                
                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)
            }
            .padding(.top, 30)
            
            // Google 登录按钮
            Button(action: { viewModel.startGoogleLogin() }) {
                HStack(spacing: 12) {
                    Text("G")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#4285F4"))
                    Text("Continue with Google")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            
            if viewModel.isWaitingForOAuth {
                Text("Waiting for browser login...")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 12)
            }
        }
    }
    
    // MARK: - Components
    
    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)
                
                Rectangle()
                    .fill(isSelected ? Theme.accent : Color.clear)
                    .frame(width: 60, height: 3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
    }
    
    @ViewBuilder
    private var messageView: some View {
        if !viewModel.successMessage.isEmpty {
            Text(viewModel.successMessage)
                .font(.system(size: 14))
                .foregroundColor(Theme.success)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.success.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.success, lineWidth: 1)
                        )
                )
                .padding(.bottom, 16)
        }
        
        if !viewModel.errorMessage.isEmpty {
            Text(viewModel.errorMessage)
                .font(.system(size: 14))
                .foregroundColor(Theme.delete)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.delete.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.delete, lineWidth: 1)
                        )
                )
                .padding(.bottom, 16)
        }
    }
    
    private func inputField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(CustomTextFieldStyle())
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .font(.system(size: 16))
            .foregroundColor(Theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    LoginView(onLoginSuccess: {})
}

