//
//  ClipboardPopupView.swift
//  Pastee
//
//  主剪贴板弹窗视图
//

import SwiftUI
import AppKit

struct ClipboardPopupView: View {
    @StateObject private var viewModel = MainViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showCategoryInput = false
    @State private var newCategoryName = ""
    @State private var editingItem: ClipboardEntry?
    
    // 删除确认
    @State private var showDeleteItemConfirm = false
    @State private var itemToDelete: ClipboardEntry?
    @State private var showDeleteCategoryConfirm = false
    @State private var categoryToDelete: Category?
    
    // 侧边栏状态
    @State private var sidebarVisible: Bool = true
    private let sidebarWidth: CGFloat = 140
    
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // 主内容
            HStack(spacing: 0) {
                // 侧边栏
                if sidebarVisible {
                    sidebarView
                        .frame(width: sidebarWidth)
                }
                
                // 主内容区
                mainContentView
            }
            .background(Theme.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .id(themeManager.isDarkMode) // 强制刷新视图以响应主题变化
            
            // Toast
            if viewModel.showToast {
                VStack {
                    Spacer()
                    Text(viewModel.toastMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Theme.surface.opacity(0.95))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // 加载保存的侧边栏状态
            let settings = SettingsManager.shared.load()
            sidebarVisible = settings.sidebarVisible
            
            Task {
                await viewModel.loadData()
            }
        }
        .onChange(of: editingItem) { newValue in
            if let item = newValue {
                showEditWindow(for: item)
                editingItem = nil
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarVisible.toggle()
        }
        
        // 保存设置
        var settings = SettingsManager.shared.load()
        settings.sidebarVisible = sidebarVisible
        SettingsManager.shared.save(settings)
        
        // 通知窗口调整大小
        let widthDelta = sidebarVisible ? sidebarWidth : -sidebarWidth
        NotificationCenter.default.post(name: .adjustWindowWidth, object: widthDelta)
    }
    
    private func showEditWindow(for item: ClipboardEntry) {
        guard item.contentType != "image" else { return }
        
        // 捕获 viewModel 引用
        let vm = viewModel
        
        // 异步调用以避免在 SwiftUI 事务中运行模态
        DispatchQueue.main.async {
            // 创建模态窗口
            let modalWindow = KeyablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 350),
                styleMask: [.borderless, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            modalWindow.isMovableByWindowBackground = true
            modalWindow.backgroundColor = .clear
            modalWindow.isOpaque = false
            modalWindow.hasShadow = true
            modalWindow.level = .modalPanel
            modalWindow.center()
            
            let editView = EditTextSheet(
                content: item.content ?? "",
                onSave: { [weak modalWindow] newContent in
                    NSApp.stopModal()
                    modalWindow?.close()
                    Task { @MainActor in
                        await vm.updateItemContent(item, newContent: newContent)
                    }
                },
                onCancel: { [weak modalWindow] in
                    NSApp.stopModal()
                    modalWindow?.close()
                }
            )
            
            let hostingView = NSHostingView(rootView: editView)
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear
            modalWindow.contentView = hostingView
            
            // 运行模态
            NSApp.activate(ignoringOtherApps: true)
            NSApp.runModal(for: modalWindow)
        }
    }
    
    private func viewImageItem(_ item: ClipboardEntry) {
        guard item.contentType == "image" else {
            print("⚡️ [ViewImage] Not an image item")
            return
        }
        
        print("⚡️ [ViewImage] displayImageData: \(item.displayImageData?.prefix(100) ?? "nil")")
        
        guard let imageDataString = item.displayImageData ?? item.content ?? item.thumbnail else {
            print("⚡️ [ViewImage] No image data available")
            return
        }
        
        var imageData: Data?
        
        // 1. 检查是否是本地文件路径
        if imageDataString.hasPrefix("/") {
            print("⚡️ [ViewImage] Loading from local file: \(imageDataString)")
            if FileManager.default.fileExists(atPath: imageDataString) {
                imageData = try? Data(contentsOf: URL(fileURLWithPath: imageDataString))
            }
        }
        
        // 2. 尝试 base64 解码
        if imageData == nil {
            var base64String = imageDataString
            
            // 移除可能的 data:image/xxx;base64, 前缀
            if base64String.contains(",") {
                base64String = String(base64String.split(separator: ",").last ?? "")
            }
            
            imageData = Data(base64Encoded: base64String)
        }
        
        guard let data = imageData, !data.isEmpty else {
            print("⚡️ [ViewImage] Failed to load image data")
            return
        }
        
        print("⚡️ [ViewImage] Opening image viewer with \(data.count) bytes")
        showImageViewer(data: data, title: "Image Viewer")
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            Text("Pastee")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 20)
            
            // 导航菜单
            VStack(alignment: .leading, spacing: 4) {
                NavButton(title: "All", isSelected: viewModel.selectedCategory == "all") {
                    viewModel.selectCategory("all")
                }
                
                NavButton(title: "Important", isSelected: viewModel.selectedCategory == "bookmarked") {
                    viewModel.selectCategory("bookmarked")
                }
                
                if viewModel.draftCount > 0 {
                    HStack {
                        NavButton(title: "Drafts", isSelected: viewModel.selectedCategory == "drafts") {
                            viewModel.selectCategory("drafts")
                        }
                        
                        Text("\(viewModel.draftCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.delete)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 12)
            
            Divider()
                .background(Theme.border)
                .padding(.vertical, 15)
                .padding(.horizontal, 12)
            
            // 分类头部
            HStack {
                Text("Categories")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Button(action: { showCategoryInput = true }) {
                    Text("+")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
                .help("Add Category")
                
                Button(action: {
                    Task { await viewModel.loadCategories() }
                }) {
                    Text("↻")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.accent)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            
            // 分类列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.categories) { category in
CategoryRow(
                                            category: category,
                                            isSelected: category.name == viewModel.selectedCategory,
                                            onSelect: { viewModel.selectCategory(category.name) },
                                            onDelete: {
                                                categoryToDelete = category
                                                showDeleteCategoryConfirm = true
                                            }
                                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            // WebSocket 状态
            Divider()
                .background(Theme.border)
                .padding(.horizontal, 12)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.wsStatusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: viewModel.wsStatusColor.opacity(0.6), radius: 4)
                
                Text(viewModel.wsStatus)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Button(action: { viewModel.reconnect() }) {
                    Text("↻")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Reconnect")
            }
            .padding(12)
        }
        .background(Theme.background)
        .alert("New Category", isPresented: $showCategoryInput) {
            TextField("Category Name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Save") {
                if !newCategoryName.isEmpty {
                    Task {
                        await viewModel.createCategory(name: newCategoryName)
                        newCategoryName = ""
                    }
                }
            }
        }
        // 删除 Category 确认
        .alert("Delete Category", isPresented: $showDeleteCategoryConfirm) {
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    Task {
                        await viewModel.deleteCategory(category)
                        categoryToDelete = nil
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(categoryToDelete?.name ?? "")\"? This action cannot be undone.")
        }
        // 删除 Item 确认
        .alert("Delete Item", isPresented: $showDeleteItemConfirm) {
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task {
                        await viewModel.deleteItem(item)
                        itemToDelete = nil
                    }
                }
            }
        } message: {
            if let item = itemToDelete {
                if item.contentType == "image" {
                    Text("Are you sure you want to delete this image? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete this item? This action cannot be undone.")
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
                // Pastee Logo (visible when sidebar is hidden)
                if !sidebarVisible {
                    Text("Pastee")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                
                Spacer()
                
                if viewModel.selectedCategory == "drafts" {
                    Button(action: { viewModel.clearDrafts() }) {
                        HStack(spacing: 4) {
                            Text("🗑")
                            Text("Clear All")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.surface)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                // Toggle Sidebar Button
                Button(action: { toggleSidebar() }) {
                    Text(sidebarVisible ? "◀" : "▶")
                        .font(.system(size: 12))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                .help(sidebarVisible ? "Hide Sidebar" : "Show Sidebar")
                
                // Settings Button
                Button(action: {
                    NotificationCenter.default.post(name: .showSettingsWindow, object: nil)
                }) {
                    Text("⚙")
                        .font(.system(size: 22))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                .help("Settings")
                
                // Search Button
                Button(action: {
                    NotificationCenter.default.post(name: .showSearchWindow, object: nil)
                }) {
                    Text("🔍")
                        .font(.system(size: 15))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                .help("Search (Ctrl+F)")
                
                Button(action: {
                    Task { await viewModel.refresh() }
                }) {
                    Text("↻")
                        .font(.system(size: 18))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                .help("Refresh")
                
                Button(action: onClose) {
                    Text("✕")
                        .font(.system(size: 15))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(IconButtonStyle())
                .help("Close (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 项目列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        // 顶部锚点
                        Color.clear.frame(height: 0).id("top")
                        
                        ForEach(viewModel.filteredItems) { item in
                            ClipboardCardView(
                                item: item,
                                onCopy: { viewModel.copyItem(item) },
                                onDelete: {
                                    itemToDelete = item
                                    showDeleteItemConfirm = true
                                },
                                onEdit: {
                                    editingItem = item
                                },
                                onViewImage: {
                                    viewImageItem(item)
                                },
                                onToggleBookmark: {
                                    Task { await viewModel.toggleBookmark(item) }
                                },
                                onRetry: {
                                    Task { await viewModel.retryUpload(item) }
                                }
                            )
                        }
                        
                        if viewModel.isLoading {
                            Text(viewModel.loadingText)
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .onChange(of: viewModel.scrollToTopTrigger) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
        .background(Theme.background)
    }
}

// MARK: - NavButton

struct NavButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CategoryRow

struct CategoryRow: View {
    let category: Category
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                Text(category.name)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // 始终占位，用 opacity 控制显隐，避免 hover 时消失
            Button(action: onDelete) {
                Text("×")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.delete)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // 确保整个区域可以检测 hover
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - IconButtonStyle

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.accent : Theme.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Theme.surfaceHover : Color.clear)
            )
    }
}

// MARK: - Preview

#Preview {
    ClipboardPopupView(onClose: {})
        .frame(width: 520, height: 500)
}

