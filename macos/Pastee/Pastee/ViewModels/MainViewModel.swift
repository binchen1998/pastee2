//
//  MainViewModel.swift
//  Pastee
//
//  主界面ViewModel
//

import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var items: [ClipboardEntry] = []
    @Published var categories: [Category] = []
    @Published var selectedCategory: String = "all"
    @Published var isLoading = false
    @Published var loadingText = "Loading..."
    @Published var wsStatus = "Connecting..."
    @Published var wsStatusColor = Color.yellow
    @Published var draftCount = 0
    @Published var showToast = false
    @Published var toastMessage = "Copied"
    
    private var currentPage = 1
    private var hasMore = true
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredItems: [ClipboardEntry] {
        switch selectedCategory {
        case "all":
            return items
        case "bookmarked":
            return items.filter { $0.isBookmarked }
        case "drafts":
            return DraftManager.shared.loadDrafts()
        default:
            return items
        }
    }
    
    // MARK: - Init
    
    init() {
        setupNotifications()
        updateDraftCount()
    }
    
    private func setupNotifications() {
        // WebSocket消息
        NotificationCenter.default.publisher(for: .webSocketMessage)
            .compactMap { $0.object as? WebSocketEvent }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleWebSocketEvent(event)
            }
            .store(in: &cancellables)
        
        // 剪贴板变化
        NotificationCenter.default.publisher(for: .clipboardChanged)
            .compactMap { $0.object as? ClipboardEntry }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                self?.handleNewClipboardEntry(entry)
            }
            .store(in: &cancellables)
        
        // WebSocket状态
        WebSocketService.shared.onConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.wsStatus = "Connected"
                self?.wsStatusColor = .green
            }
        }
        
        WebSocketService.shared.onDisconnected = { [weak self] in
            DispatchQueue.main.async {
                self?.wsStatus = "Disconnected"
                self?.wsStatusColor = .red
            }
        }
        
        // 检查当前连接状态（可能在设置回调前已经连接）
        if WebSocketService.shared.isConnected {
            wsStatus = "Connected"
            wsStatusColor = .green
        }
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        guard !isLoading else { return }
        
        isLoading = true
        loadingText = "Loading..."
        currentPage = 1
        hasMore = true
        
        do {
            let response = try await APIService.shared.getClipboardItems(page: 1, category: selectedCategory)
            
            var loadedItems = response.items
            for i in loadedItems.indices {
                loadedItems[i].initializeImageState()
            }
            
            items = loadedItems
            hasMore = response.hasMoreItems
            currentPage = 1
            
            // 自动下载原图
            for item in loadedItems {
                if item.contentType == "image" && item.isThumbnail && !(item.originalDeleted ?? false) {
                    Task {
                        await autoDownloadOriginalImage(item)
                    }
                }
            }
        } catch {
            print("Failed to load items: \(error)")
        }
        
        isLoading = false
        
        // 同时加载分类
        await loadCategories()
        updateDraftCount()
    }
    
    // MARK: - 自动下载原图
    
    private func autoDownloadOriginalImage(_ item: ClipboardEntry) async {
        // 随机延迟 300-2000ms，避免同时发起大量请求
        let delay = UInt64.random(in: 300_000_000...2_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
        
        do {
            // API返回的是base64字符串
            if let base64String = try await APIService.shared.getOriginalImage(id: item.id) {
                // 更新对应项目的图片数据
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].displayImageData = base64String
                    items[index].isThumbnail = false
                    print("[MainVM] Original image downloaded for: \(item.id)")
                }
            }
        } catch {
            print("[MainVM] Failed to download original image: \(error)")
        }
    }
    
    func loadMore() async {
        guard !isLoading && hasMore else { return }
        
        isLoading = true
        loadingText = "Loading more..."
        
        do {
            let response = try await APIService.shared.getClipboardItems(page: currentPage + 1, category: selectedCategory)
            
            var loadedItems = response.items
            for i in loadedItems.indices {
                loadedItems[i].initializeImageState()
            }
            
            items.append(contentsOf: loadedItems)
            hasMore = response.hasMoreItems
            currentPage += 1
        } catch {
            print("Failed to load more items: \(error)")
        }
        
        isLoading = false
    }
    
    func loadCategories() async {
        do {
            var loadedCategories = try await APIService.shared.getCategories()
            
            // 更新选中状态
            for i in loadedCategories.indices {
                loadedCategories[i].isSelected = loadedCategories[i].name == selectedCategory
            }
            
            categories = loadedCategories
        } catch {
            print("Failed to load categories: \(error)")
        }
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Category Actions
    
    func selectCategory(_ category: String) {
        selectedCategory = category
        
        // 更新分类选中状态
        for i in categories.indices {
            categories[i].isSelected = categories[i].name == category
        }
        
        Task {
            await loadData()
        }
    }
    
    func createCategory(name: String) async {
        do {
            _ = try await APIService.shared.createCategory(name: name)
            await loadCategories()
        } catch {
            print("Failed to create category: \(error)")
        }
    }
    
    func deleteCategory(_ category: Category) async {
        do {
            try await APIService.shared.deleteCategory(id: category.id)
            await loadCategories()
        } catch {
            print("Failed to delete category: \(error)")
        }
    }
    
    // MARK: - Item Actions
    
    func copyItem(_ item: ClipboardEntry) {
        ClipboardWatcher.shared.ignoreNext()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if item.contentType == "image", let imageData = item.displayImageData {
            // 处理Base64图片
            var base64String = imageData
            if base64String.contains(",") {
                base64String = String(base64String.split(separator: ",").last ?? "")
            }
            base64String = base64String.replacingOccurrences(of: "\n", with: "")
                                       .replacingOccurrences(of: "\r", with: "")
            
            if let data = Data(base64Encoded: base64String), let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        } else if let content = item.content {
            pasteboard.setString(content, forType: .string)
        }
        
        showToastMessage("Copied")
        
        // 如果设置了"隐藏后粘贴"，通过通知触发粘贴
        let settings = SettingsManager.shared.load()
        print("⚡️ [MainVM] copyItem completed, hideAfterPaste: \(settings.hideAfterPaste)")
        if settings.hideAfterPaste {
            print("⚡️ [MainVM] Posting pasteToFocusedApp notification NOW")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .pasteToFocusedApp, object: nil)
                print("⚡️ [MainVM] Notification posted")
            }
        }
    }
    
    func deleteItem(_ item: ClipboardEntry) async {
        // 如果是草稿，不调用API
        if item.uploadFailed {
            DraftManager.shared.removeDraft(item)
            updateDraftCount()
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
            }
            return
        }
        
        do {
            try await APIService.shared.deleteItem(id: item.id)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items.remove(at: index)
            }
        } catch {
            print("Failed to delete item: \(error)")
        }
    }
    
    func toggleBookmark(_ item: ClipboardEntry) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        let newValue = !item.isBookmarked
        items[index].isBookmarked = newValue
        
        do {
            try await APIService.shared.toggleBookmark(id: item.id, isBookmarked: newValue)
            print("⚡️ [MainVM] Bookmark toggled: \(item.id) -> \(newValue)")
        } catch {
            // 恢复状态
            items[index].isBookmarked = !newValue
            print("⚡️ [MainVM] Toggle bookmark failed: \(error)")
        }
    }
    
    @MainActor
    func updateItemContent(_ item: ClipboardEntry, newContent: String) async {
        do {
            try await APIService.shared.updateItemContent(id: item.id, content: newContent)
            // 在主线程上查找并更新
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                var newItem = items[index]
                newItem.content = newContent
                items[index] = newItem
                print("⚡️ [MainVM] Content updated: \(item.id)")
            }
        } catch {
            print("⚡️ [MainVM] Failed to update item: \(error)")
        }
    }
    
    func retryUpload(_ item: ClipboardEntry) async {
        guard var entry = items.first(where: { $0.id == item.id }) else { return }
        
        entry.isUploading = true
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = entry
        }
        
        do {
            if entry.contentType == "image" {
                // 重新上传图片需要原始数据
                // 这里简化处理
            } else if let content = entry.content {
                _ = try await APIService.shared.uploadTextItem(
                    content: content,
                    contentType: entry.contentType,
                    deviceId: AuthService.shared.getDeviceId(),
                    createdAt: entry.createdAt
                )
            }
            
            DraftManager.shared.removeDraft(entry)
            entry.uploadFailed = false
            entry.isUploading = false
            
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = entry
            }
            updateDraftCount()
        } catch {
            entry.isUploading = false
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = entry
            }
        }
    }
    
    func addItemToCategory(_ item: ClipboardEntry, category: Category) async {
        do {
            try await APIService.shared.addItemToCategory(categoryId: category.id, itemId: item.id)
            showToastMessage("Added to \(category.name)")
        } catch {
            print("Failed to add item to category: \(error)")
        }
    }
    
    // MARK: - Drafts
    
    func clearDrafts() {
        DraftManager.shared.clearAllDrafts()
        updateDraftCount()
        if selectedCategory == "drafts" {
            items = []
        }
    }
    
    private func updateDraftCount() {
        draftCount = DraftManager.shared.draftCount
    }
    
    // MARK: - WebSocket
    
    func reconnect() {
        WebSocketService.shared.reconnect()
    }
    
    private func handleWebSocketEvent(_ event: WebSocketEvent) {
        switch event {
        case .newItem(var item):
            // 避免重复
            if !items.contains(where: { $0.id == item.id }) {
                // 确保图片状态已初始化
                item.initializeImageState()
                items.insert(item, at: 0)
                print("[WebSocket] New item inserted: \(item.id)")
                
                // 如果是图片且是缩略图，自动下载原图
                if item.contentType == "image" && item.isThumbnail && !(item.originalDeleted ?? false) {
                    Task {
                        await autoDownloadOriginalImage(item)
                    }
                }
            }
        case .updateItem(let updatedItem):
            // WebSocket update_item 只包含部分字段 (id, content)，只更新 content
            if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
                var existingItem = items[index]
                existingItem.content = updatedItem.content
                items[index] = existingItem
                print("[WebSocket] Item content updated: \(updatedItem.id)")
            }
        case .deleteItem(let itemId):
            items.removeAll { $0.id == itemId }
            print("[WebSocket] Item deleted: \(itemId)")
        case .sync:
            Task {
                await loadData()
            }
        case .unknown(let text):
            print("[WebSocket] Unknown event: \(text)")
        }
    }
    
    private func handleNewClipboardEntry(_ entry: ClipboardEntry) {
        // 本地添加到列表顶部
        if !items.contains(where: { $0.id == entry.id }) {
            items.insert(entry, at: 0)
        }
    }
    
    // MARK: - Toast
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showToast = false
        }
    }
}

