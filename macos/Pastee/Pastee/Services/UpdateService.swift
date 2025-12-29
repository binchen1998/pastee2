//
//  UpdateService.swift
//  Pastee
//
//  自动更新服务
//

import Foundation
import AppKit
import SwiftUI

class UpdateService {
    static let shared = UpdateService()
    
    private let baseURL = "https://api.pastee-app.com"
    private var lastCheckTime: Date?
    private let checkInterval: TimeInterval = 6 * 60 * 60 // 6小时
    
    var onUpdateAvailable: ((VersionCheckResponse) -> Void)?
    
    private init() {}
    
    // MARK: - Check for Update
    
    func checkForUpdate() async {
        // 检查是否需要检查更新
        if let lastCheck = lastCheckTime, Date().timeIntervalSince(lastCheck) < checkInterval {
            return
        }
        
        guard let token = AuthService.shared.getToken() else { return }
        
        do {
            let response = try await performCheck(token: token)
            lastCheckTime = Date()
            
            if response.updateAvailable {
                DispatchQueue.main.async {
                    self.onUpdateAvailable?(response)
                    self.showUpdateWindow(response: response)
                }
            }
        } catch {
            print("Update check failed: \(error)")
        }
    }
    
    func forceCheck() async -> VersionCheckResponse? {
        guard let token = AuthService.shared.getToken() else { return nil }
        
        do {
            let response = try await performCheck(token: token)
            lastCheckTime = Date()
            return response
        } catch {
            print("Update check failed: \(error)")
            return nil
        }
    }
    
    private func performCheck(token: String) async throws -> VersionCheckResponse {
        let url = URL(string: "\(baseURL)/version/check")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let body = ["current_version": currentVersion]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(VersionCheckResponse.self, from: data)
    }
    
    // MARK: - Download Update
    
    func downloadUpdate(url: String, progress: @escaping (Double) -> Void) async throws -> URL {
        guard let downloadURL = URL(string: url) else {
            throw UpdateError.invalidURL
        }
        
        let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
        
        // 移动到下载目录
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destURL = downloadsDir.appendingPathComponent(downloadURL.lastPathComponent)
        
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        
        return destURL
    }
    
    func openDMG(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Update Window
    
    private func showUpdateWindow(response: VersionCheckResponse) {
        let updateView = UpdatePromptView(
            response: response,
            onUpdate: { [weak self] in
                Task {
                    await self?.handleUpdate(response: response)
                }
            },
            onLater: {
                // 关闭窗口
                NSApp.keyWindow?.close()
            }
        )
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .floating
        window.center()
        window.contentView = NSHostingView(rootView: updateView)
        
        if response.mandatory {
            // 强制更新时禁用关闭按钮
            window.standardWindowButton(.closeButton)?.isEnabled = false
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func handleUpdate(response: VersionCheckResponse) async {
        guard let downloadUrl = response.downloadUrl else { return }
        
        do {
            let dmgURL = try await downloadUpdate(url: downloadUrl) { progress in
                print("Download progress: \(progress * 100)%")
            }
            openDMG(dmgURL)
        } catch {
            print("Download failed: \(error)")
        }
    }
}

enum UpdateError: Error {
    case invalidURL
    case downloadFailed
}

