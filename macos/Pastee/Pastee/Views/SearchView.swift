//
//  SearchView.swift
//  Pastee
//
//  搜索界面
//

import SwiftUI
import AppKit

struct SearchView: View {
    @State private var searchText = ""
    @State private var results: [ClipboardEntry] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var showToast = false
    @State private var currentPage = 1
    @State private var hasMore = false
    @State private var shouldFocusSearchField = false
    
    let onSelect: (ClipboardEntry) -> Void
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 头部
                HStack {
                    Text("🔍 Search Clips")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { closeWindow() }) {
                        Text("✕")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 15)
                
                // 搜索输入框
                HStack {
                    FocusableTextField(
                        text: $searchText,
                        placeholder: "Type and press Enter to search...",
                        shouldFocus: $shouldFocusSearchField,
                        onSubmit: {
                            Task { await search() }
                        }
                    )
                    .frame(height: 20)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            results = []
                            hasSearched = false
                        }) {
                            Text("✕")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.surface)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
                
                // 结果列表
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(results) { item in
                            SearchResultCard(item: item) {
                                copyItem(item)
                            }
                        }
                        
                        // 加载更多
                        if hasMore && !isSearching {
                            Button(action: {
                                Task { await loadMore() }
                            }) {
                                Text("Load More")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            .padding()
                        }
                        
                        // 状态指示器
                        if isSearching {
                            Text("Searching...")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textSecondary)
                                .padding(20)
                        } else if hasSearched && results.isEmpty {
                            VStack(spacing: 10) {
                                Text("😔")
                                    .font(.system(size: 32))
                                Text("No results found")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(40)
                        } else if !hasSearched {
                            VStack(spacing: 10) {
                                Text("🔎")
                                    .font(.system(size: 32))
                                Text("Press Enter to search")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(40)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            
            // Toast
            if showToast {
                VStack {
                    Spacer()
                    Text("Copied")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Theme.surface.opacity(0.95))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        .padding(.bottom, 20)
                }
            }
        }
        .frame(width: 480, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .onAppear {
            // 延迟一点设置焦点，确保视图已完全加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                shouldFocusSearchField = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func search() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        currentPage = 1
        
        do {
            let response = try await APIService.shared.searchItems(query: searchText, page: 1)
            var items = response.items
            for i in items.indices {
                items[i].initializeImageState()
            }
            results = items
            hasMore = response.hasMoreItems
        } catch {
            results = []
        }
        
        isSearching = false
    }
    
    private func loadMore() async {
        guard hasMore else { return }
        
        isSearching = true
        
        do {
            let response = try await APIService.shared.searchItems(query: searchText, page: currentPage + 1)
            var items = response.items
            for i in items.indices {
                items[i].initializeImageState()
            }
            results.append(contentsOf: items)
            hasMore = response.hasMoreItems
            currentPage += 1
        } catch {
            // 忽略错误
        }
        
        isSearching = false
    }
    
    private func copyItem(_ item: ClipboardEntry) {
        ClipboardWatcher.shared.ignoreNext()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if item.contentType == "image", let imageData = item.displayImageData {
            if let data = Data(base64Encoded: imageData), let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        } else if let content = item.content {
            pasteboard.setString(content, forType: .string)
        }
        
        showToastMessage()
        onSelect(item)
    }
    
    private func showToastMessage() {
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showToast = false
        }
    }
    
    private func closeWindow() {
        // 查找包含此视图的窗口并关闭
        if let window = NSApp.windows.first(where: { $0.contentView is NSHostingView<SearchView> }) {
            window.close()
        } else {
            NSApp.keyWindow?.close()
        }
    }
}

// MARK: - SearchResultCard

struct SearchResultCard: View {
    let item: ClipboardEntry
    let onTap: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 内容
            if item.contentType == "image" {
                if let imageData = item.displayImageData,
                   let data = Data(base64Encoded: imageData),
                   let nsImage = NSImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 80)
                            .background(Theme.background)
                            .cornerRadius(6)
                        
                        if item.isThumbnail {
                            Text("thumbnail")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(4)
                                .padding(8)
                        }
                    }
                }
            } else {
                Text(item.content ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(3)
            }
            
            // 时间
            Text(relativeTime(from: item.createdAt))
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Theme.surfaceHover : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovering ? Theme.accent : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - FocusableTextField

struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var shouldFocus: Bool
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 14)
        textField.textColor = NSColor(Theme.textPrimary)
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // 当 shouldFocus 变为 true 时，让窗口成为 key 并聚焦到输入框
        if shouldFocus {
            DispatchQueue.main.async {
                if let window = nsView.window {
                    window.makeKey()
                    window.makeFirstResponder(nsView)
                }
                shouldFocus = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusableTextField
        
        init(_ parent: FocusableTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - Preview

#Preview {
    SearchView(onSelect: { _ in })
}

