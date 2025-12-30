import Foundation
import AppKit

/// 图片缓存服务 - 用于缓存原图到本地
class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    private init() {
        // 使用 Application Support 目录存储缓存
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("Pastee/ImageCache", isDirectory: true)
        
        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        print("⚡️ [ImageCache] Cache directory: \(cacheDirectory.path)")
    }
    
    /// 获取缓存的原图路径
    /// - Parameter id: 剪贴板项目ID
    /// - Returns: 缓存文件路径，如果不存在返回nil
    func getCachedOriginalImagePath(id: String) -> String? {
        let fileName = "orig_\(id).png"
        let filePath = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: filePath.path) {
            print("⚡️ [ImageCache] Cache hit: \(id)")
            return filePath.path
        }
        
        print("⚡️ [ImageCache] Cache miss: \(id)")
        return nil
    }
    
    /// 获取缓存的原图 Base64 数据
    /// - Parameter id: 剪贴板项目ID
    /// - Returns: Base64编码的图片数据，如果不存在返回nil
    func getCachedOriginalImageData(id: String) -> String? {
        guard let path = getCachedOriginalImagePath(id: id) else { return nil }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return data.base64EncodedString()
        } catch {
            print("⚡️ [ImageCache] Failed to read cache: \(error)")
            return nil
        }
    }
    
    /// 保存原图到缓存
    /// - Parameters:
    ///   - id: 剪贴板项目ID
    ///   - base64Data: Base64编码的图片数据
    /// - Returns: 保存的文件路径
    @discardableResult
    func saveOriginalImage(id: String, base64Data: String) -> String? {
        let fileName = "orig_\(id).png"
        let filePath = cacheDirectory.appendingPathComponent(fileName)
        
        // 清理 base64 前缀
        var cleanBase64 = base64Data
        if cleanBase64.contains(",") {
            cleanBase64 = String(cleanBase64.split(separator: ",").last ?? "")
        }
        cleanBase64 = cleanBase64.replacingOccurrences(of: "\n", with: "")
                                  .replacingOccurrences(of: "\r", with: "")
                                  .trimmingCharacters(in: .whitespaces)
        
        guard let data = Data(base64Encoded: cleanBase64) else {
            print("⚡️ [ImageCache] Invalid base64 data for: \(id)")
            return nil
        }
        
        do {
            try data.write(to: filePath)
            print("⚡️ [ImageCache] Saved: \(id) to \(filePath.path)")
            return filePath.path
        } catch {
            print("⚡️ [ImageCache] Failed to save: \(error)")
            return nil
        }
    }
    
    /// 保存原图到缓存 (从 Data)
    /// - Parameters:
    ///   - id: 剪贴板项目ID
    ///   - imageData: 图片二进制数据
    /// - Returns: 保存的文件路径
    @discardableResult
    func saveOriginalImage(id: String, imageData: Data) -> String? {
        let fileName = "orig_\(id).png"
        let filePath = cacheDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: filePath)
            print("⚡️ [ImageCache] Saved from Data: \(id)")
            return filePath.path
        } catch {
            print("⚡️ [ImageCache] Failed to save from Data: \(error)")
            return nil
        }
    }
    
    /// 清理所有缓存
    func clearCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
            print("⚡️ [ImageCache] Cache cleared")
        } catch {
            print("⚡️ [ImageCache] Failed to clear cache: \(error)")
        }
    }
    
    /// 获取缓存大小
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(attributes.fileSize ?? 0)
            }
        } catch {
            print("⚡️ [ImageCache] Failed to get cache size: \(error)")
        }
        
        return totalSize
    }
}

