//
//  UpdateView.swift
//  Pastee
//
//  更新提示界面
//

import SwiftUI

struct UpdatePromptView: View {
    let response: VersionCheckResponse
    let onUpdate: () -> Void
    let onLater: () -> Void
    
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var errorMessage = ""
    
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 关闭按钮（非强制更新时显示）
                if !response.mandatory {
                    HStack {
                        Spacer()
                        Button(action: onLater) {
                            Text("✕")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.textSecondary)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 15)
                    .padding(.trailing, 15)
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 图标
                        Text("🚀")
                            .font(.system(size: 48))
                            .padding(.top, response.mandatory ? 40 : 0)
                            .padding(.bottom, 16)
                        
                        // 标题
                        Text("New Version Available!")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.bottom, 8)
                        
                        // 版本信息
                        HStack(spacing: 4) {
                            Text("Current:")
                                .foregroundColor(Theme.textSecondary)
                            Text(currentVersion)
                                .foregroundColor(Theme.textSecondary)
                            Text("→")
                                .foregroundColor(Theme.textSecondary)
                            Text("Latest:")
                                .foregroundColor(Theme.textSecondary)
                            Text(response.version)
                                .foregroundColor(Theme.accent)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14))
                        .padding(.bottom, 16)
                        
                        // 强制更新警告
                        if response.mandatory {
                            HStack(spacing: 8) {
                                Text("⚠")
                                Text("This is a mandatory update. You must update to continue using the app.")
                            }
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
                        
                        // 更新说明
                        if let releaseNotes = response.releaseNotes, !releaseNotes.isEmpty {
                            ScrollView {
                                Text(releaseNotes)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 100)
                            .padding(12)
                            .background(Theme.surface)
                            .cornerRadius(6)
                            .padding(.bottom, 20)
                        }
                        
                        // 下载进度
                        if isDownloading {
                            VStack(spacing: 8) {
                                Text("Downloading...")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                                
                                ProgressView(value: downloadProgress)
                                    .progressViewStyle(.linear)
                                    .accentColor(Theme.accent)
                                
                                Text("\(Int(downloadProgress * 100))%")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.bottom, 20)
                        }
                        
                        // 错误信息
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
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
                        
                        // 按钮
                        if !isDownloading {
                            HStack(spacing: 12) {
                                Button(action: {
                                    startDownload()
                                }) {
                                    Text("Update Now")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Theme.background)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Theme.accent)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                if !response.mandatory {
                                    Button(action: onLater) {
                                        Text("Later")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.textPrimary)
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Theme.surface)
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
        }
        .frame(width: 450, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
    
    private func startDownload() {
        guard let urlString = response.downloadUrl else {
            errorMessage = "Download URL not available"
            return
        }
        
        isDownloading = true
        errorMessage = ""
        
        Task {
            do {
                let pkgURL = try await UpdateService.shared.downloadUpdate(url: urlString) { progress in
                    DispatchQueue.main.async {
                        downloadProgress = progress
                    }
                }
                
                await MainActor.run {
                    isDownloading = false
                    UpdateService.shared.openPKG(pkgURL)
                    onUpdate()
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    errorMessage = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UpdatePromptView(
        response: VersionCheckResponse(
            updateAvailable: true,
            latestVersion: "1.1.0",
            isMandatory: false,
            releaseNotes: "Bug fixes and improvements",
            downloadUrl: nil
        ),
        onUpdate: {},
        onLater: {}
    )
}

