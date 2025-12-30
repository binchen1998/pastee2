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
    @State private var showCategoryInput = false
    @State private var newCategoryName = ""
    @State private var editingItem: ClipboardEntry?
    
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // 主内容
            HStack(spacing: 0) {
                // 侧边栏
                sidebarView
                    .frame(width: 140)
                
                // 分隔线
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1)
                
                // 主内容区
                mainContentView
            }
            .background(Theme.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
            
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
        
        print("⚡️ [ViewImage] displayImageData: \(item.displayImageData?.prefix(50) ?? "nil")")
        print("⚡️ [ViewImage] content: \(item.content?.prefix(50) ?? "nil")")
        print("⚡️ [ViewImage] thumbnail: \(item.thumbnail?.prefix(50) ?? "nil")")
        
        // 获取图片数据 - 优先使用 displayImageData，然后是 content，最后是 thumbnail
        var base64String: String? = item.displayImageData ?? item.content ?? item.thumbnail
        
        // 移除可能的 data:image/xxx;base64, 前缀
        if let str = base64String, str.contains(",") {
            base64String = String(str.split(separator: ",").last ?? "")
        }
        
        guard let base64 = base64String, !base64.isEmpty else {
            print("⚡️ [ViewImage] No image data available")
            return
        }
        
        guard let data = Data(base64Encoded: base64) else {
            print("⚡️ [ViewImage] Failed to decode base64, length: \(base64.count)")
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
                
                NavButton(title: "Settings", isSelected: false) {
                    // 使用 NotificationCenter 通知打开设置
                    NotificationCenter.default.post(name: .showSettingsWindow, object: nil)
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
                                Task { await viewModel.deleteCategory(category) }
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
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // 顶部操作栏
            HStack {
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
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(viewModel.filteredItems) { item in
                        ClipboardCardView(
                            item: item,
                            onCopy: { viewModel.copyItem(item) },
                            onDelete: {
                                Task { await viewModel.deleteItem(item) }
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
            
            if isHovering {
                Button(action: onDelete) {
                    Text("×")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.delete)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
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

