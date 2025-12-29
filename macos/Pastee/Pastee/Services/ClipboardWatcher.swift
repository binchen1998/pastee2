//
//  ClipboardWatcher.swift
//  Pastee
//
//  剪贴板监控服务
//

import Foundation
import AppKit

class ClipboardWatcher {
    static let shared = ClipboardWatcher()
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastSignature: String?
    private var isIgnoringNext = false
    
    var onNewContent: ((ClipboardEntry) -> Void)?
    
    private init() {}
    
    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 暂时忽略下一次剪贴板变化（用于自己粘贴时）
    func ignoreNext() {
        isIgnoringNext = true
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        if isIgnoringNext {
            isIgnoringNext = false
            return
        }
        
        // 检查图片
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            handleImage(image)
            return
        }
        
        // 检查文本
        if let string = pasteboard.string(forType: .string) {
            handleText(string)
            return
        }
    }
    
    private func handleText(_ text: String) {
        let signature = "text:\(text.hashValue)"
        if signature == lastSignature { return }
        lastSignature = signature
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let entry = ClipboardEntry(
            id: UUID().uuidString,
            contentType: isURL(trimmedText) ? "url" : "text",
            content: trimmedText,
            createdAt: Date(),
            isBookmarked: false
        )
        
        onNewContent?(entry)
        NotificationCenter.default.post(name: .clipboardChanged, object: entry)
        
        // 上传到服务器
        uploadEntry(entry)
    }
    
    private func handleImage(_ image: NSImage) {
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        let signature = "image:\(pngData.count)"
        if signature == lastSignature { return }
        lastSignature = signature
        
        // 生成缩略图作为预览
        let base64Thumbnail = generateThumbnail(from: image)
        
        var entry = ClipboardEntry(
            id: UUID().uuidString,
            contentType: "image",
            createdAt: Date(),
            isBookmarked: false
        )
        entry.displayImageData = base64Thumbnail
        entry.isThumbnail = true
        
        onNewContent?(entry)
        NotificationCenter.default.post(name: .clipboardChanged, object: entry)
        
        // 上传到服务器
        uploadImageEntry(entry, imageData: pngData)
    }
    
    private func generateThumbnail(from image: NSImage) -> String? {
        let maxSize: CGFloat = 200
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height, 1)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        return jpegData.base64EncodedString()
    }
    
    private func isURL(_ text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.count == 1 && matches.first?.range == range
    }
    
    private func uploadEntry(_ entry: ClipboardEntry) {
        guard let content = entry.content else { return }
        let deviceId = AuthService.shared.getDeviceId()
        
        Task {
            do {
                _ = try await APIService.shared.uploadTextItem(
                    content: content,
                    contentType: entry.contentType,
                    deviceId: deviceId,
                    createdAt: entry.createdAt
                )
            } catch APIError.conflict {
                // 重复项，忽略
            } catch {
                // 上传失败，保存为草稿
                var failedEntry = entry
                failedEntry.uploadFailed = true
                DraftManager.shared.saveDraft(failedEntry)
            }
        }
    }
    
    private func uploadImageEntry(_ entry: ClipboardEntry, imageData: Data) {
        let deviceId = AuthService.shared.getDeviceId()
        
        Task {
            do {
                _ = try await APIService.shared.uploadImageItem(
                    imageData: imageData,
                    deviceId: deviceId,
                    createdAt: entry.createdAt
                )
            } catch APIError.conflict {
                // 重复项，忽略
            } catch {
                // 上传失败，保存为草稿
                var failedEntry = entry
                failedEntry.uploadFailed = true
                DraftManager.shared.saveDraft(failedEntry)
            }
        }
    }
}

// MARK: - Draft Manager

class DraftManager {
    static let shared = DraftManager()
    
    private var pasteeDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pastee")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var draftFile: URL { pasteeDir.appendingPathComponent("clipboard.json") }
    
    private init() {}
    
    func saveDraft(_ entry: ClipboardEntry) {
        var drafts = loadDrafts()
        drafts.removeAll { $0.id == entry.id }
        drafts.append(entry)
        save(drafts)
    }
    
    func removeDraft(_ entry: ClipboardEntry) {
        var drafts = loadDrafts()
        drafts.removeAll { $0.id == entry.id }
        save(drafts)
    }
    
    func loadDrafts() -> [ClipboardEntry] {
        guard let data = try? Data(contentsOf: draftFile),
              let entries = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else {
            return []
        }
        return entries.filter { $0.uploadFailed }
    }
    
    func clearAllDrafts() {
        try? FileManager.default.removeItem(at: draftFile)
    }
    
    var draftCount: Int {
        loadDrafts().count
    }
    
    private func save(_ entries: [ClipboardEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: draftFile)
    }
}

