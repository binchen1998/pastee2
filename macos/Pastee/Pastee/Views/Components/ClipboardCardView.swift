//
//  ClipboardCardView.swift
//  Pastee
//
//  剪贴板项目卡片组件
//

import SwiftUI
import AppKit

struct ClipboardCardView: View {
    let item: ClipboardEntry
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onViewImage: () -> Void
    let onToggleBookmark: () -> Void
    let onRetry: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        // 内容区域
        contentView
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Theme.surfaceHover : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovering ? Theme.accent : Color.clear, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            statusIndicator
        }
        .overlay(alignment: .bottomLeading) {
            // 时间 overlay（悬停时显示）
            Text(relativeTime(from: item.createdAt))
                .font(.system(size: 10))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .padding(6)
                .opacity(isHovering ? 1 : 0)
        }
        .overlay(alignment: .bottomTrailing) {
            // 操作按钮（悬停时显示）
            actionButtons
                .padding(6)
                .opacity(isHovering ? 1 : 0)
        }
        .overlay(alignment: .bottomTrailing) {
            downloadingIndicator
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onCopy()
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if item.contentType == "image" {
            imageContent
        } else {
            textContent
        }
    }
    
    private var textContent: some View {
        Text(item.content ?? "")
            .font(.system(size: 13))
            .foregroundColor(Theme.textPrimary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
    }
    
    private var imageContent: some View {
        ZStack(alignment: .topLeading) {
            // 图片内容
            if let nsImage = loadImage() {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 100)
                    .frame(maxWidth: .infinity)
                    .background(Theme.background)
                    .cornerRadius(6)
            } else {
                Rectangle()
                    .fill(Theme.background)
                    .frame(height: 100)
                    .cornerRadius(6)
                    .overlay(
                        VStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Theme.textSecondary)
                    )
            }
            
            // 状态指示器在卡片层级通过 statusIndicator 显示，这里不重复
            
            // 右上角缩略图标志
            if item.isThumbnail && !item.isUploading && !item.uploadFailed {
                VStack {
                    HStack {
                        Spacer()
                        Text("thumbnail")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
    }
    
    // 加载图片：支持Base64、本地路径、URL
    private func loadImage() -> NSImage? {
        guard let imageData = item.displayImageData else { return nil }
        
        // 1. 优先尝试本地文件路径（以 /Users 或 /var 等开头的完整路径）
        if imageData.hasPrefix("/Users") || imageData.hasPrefix("/var") || imageData.hasPrefix("/tmp") {
            if FileManager.default.fileExists(atPath: imageData),
               let image = NSImage(contentsOfFile: imageData) {
                return image
            }
        }
        
        // 2. 尝试Base64解码
        if isBase64Like(imageData) {
            var base64String = imageData
            // 处理 data:image/xxx;base64, 前缀
            if base64String.contains(",") {
                base64String = String(base64String.split(separator: ",").last ?? "")
            }
            // 清理换行符
            base64String = base64String.replacingOccurrences(of: "\n", with: "")
                                       .replacingOccurrences(of: "\r", with: "")
                                       .trimmingCharacters(in: .whitespaces)
            
            if let data = Data(base64Encoded: base64String),
               let image = NSImage(data: data) {
                return image
            }
        }
        
        // 3. 尝试远程URL加载
        if imageData.hasPrefix("http") {
            if let url = URL(string: imageData),
               let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                return image
            }
        }
        
        // 4. 尝试相对API路径
        if imageData.hasPrefix("/") {
            let urlString = "https://api.pastee-app.com\(imageData)"
            if let url = URL(string: urlString),
               let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                return image
            }
        }
        
        // 5. 最后尝试作为任意本地文件路径
        if FileManager.default.fileExists(atPath: imageData),
           let image = NSImage(contentsOfFile: imageData) {
            return image
        }
        
        return nil
    }
    
    private func isBase64Like(_ string: String) -> Bool {
        if string.hasPrefix("data:image") { return true }
        if string.count < 100 { return false }
        if string.hasPrefix("http") || string.hasPrefix("/") { return false }
        return true
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        if item.isUploading {
            HStack(spacing: 4) {
                Text("⏳")
                    .font(.system(size: 10))
                Text("Uploading...")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)
            .offset(x: -4, y: -4)
        } else if item.uploadFailed {
            HStack(spacing: 4) {
                Text("⚠")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.delete)
                Text("Failed")
                    .font(.system(size: 10))
                Text("↻")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.red.opacity(0.8))
            .cornerRadius(4)
            .offset(x: -4, y: -4)
            .onTapGesture {
                onRetry()
            }
            .help("Click to Retry Upload")
        }
    }
    
    // MARK: - Downloading Indicator
    
    @ViewBuilder
    private var downloadingIndicator: some View {
        if item.isDownloadingOriginal {
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("Downloading...")
                    .font(.system(size: 9))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.6))
            .cornerRadius(4)
            .padding(6)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if item.contentType != "image" {
                Button(action: onEdit) {
                    Text("✎")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Edit")
            } else {
                Button(action: onViewImage) {
                    Text("👁")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("View Image")
            }
            
            Button(action: onDelete) {
                Text("🗑")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.delete)
            }
            .buttonStyle(.plain)
            .help("Delete")
            
            // Bookmark Button
            Button(action: onToggleBookmark) {
                Text(item.isBookmarked ? "❤" : "♡")
                    .font(.system(size: 17))
                    .foregroundColor(item.isBookmarked ? Theme.delete : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Bookmark")
        }
    }
    
    // MARK: - Helper
    
    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 10) {
        ClipboardCardView(
            item: ClipboardEntry(content: "Hello, World! This is a test clipboard entry."),
            onCopy: {},
            onDelete: {},
            onEdit: {},
            onViewImage: {},
            onToggleBookmark: {},
            onRetry: {}
        )
        
        ClipboardCardView(
            item: ClipboardEntry(contentType: "image", content: nil),
            onCopy: {},
            onDelete: {},
            onEdit: {},
            onViewImage: {},
            onToggleBookmark: {},
            onRetry: {}
        )
    }
    .padding()
    .background(Theme.background)
}

