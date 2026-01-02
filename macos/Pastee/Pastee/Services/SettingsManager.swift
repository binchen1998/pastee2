//
//  SettingsManager.swift
//  Pastee
//
//  设置管理器
//

import Foundation
import ServiceManagement

class SettingsManager {
    static let shared = SettingsManager()
    
    private var pasteeDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pastee")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var settingsFile: URL { pasteeDir.appendingPathComponent("settings.json") }
    private var imagesDir: URL { pasteeDir.appendingPathComponent("images") }
    
    private init() {
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Load/Save Settings
    
    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsFile),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }
    
    func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: settingsFile)
    }
    
    // MARK: - Launch at Login
    
    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set launch at login: \(error)")
            }
        } else {
            // 旧版本系统
            let helperBundleId = "im.pastee.app.LaunchHelper" as CFString
            SMLoginItemSetEnabled(helperBundleId, enabled)
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        // 清除图片缓存
        try? FileManager.default.removeItem(at: imagesDir)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        // 清除草稿
        DraftManager.shared.clearAllDrafts()
    }
    
    func getCacheSize() -> String {
        var totalSize: Int64 = 0
        
        if let enumerator = FileManager.default.enumerator(at: imagesDir, includingPropertiesForKeys: [.fileSizeKey]) {
            while let url = enumerator.nextObject() as? URL {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    // MARK: - Image Cache
    
    func saveImage(_ data: Data, id: String) -> URL? {
        let imageFile = imagesDir.appendingPathComponent("\(id).png")
        do {
            try data.write(to: imageFile)
            return imageFile
        } catch {
            return nil
        }
    }
    
    func getImage(id: String) -> Data? {
        let imageFile = imagesDir.appendingPathComponent("\(id).png")
        return try? Data(contentsOf: imageFile)
    }
}


