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
        VStack(alignment: .leading, spacing: 4) {
            // 内容区域
            contentView
            
            // 时间和操作按钮（始终占位，悬停时显示）
            HStack {
                Text(relativeTime(from: item.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                actionButtons
            }
            .padding(.top, 4)
            .opacity(isHovering ? 1 : 0)
        }
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
        .overlay(alignment: .topTrailing) {
            bookmarkButton
                .offset(x: 5, y: -5)
                .opacity(isHovering ? 1 : 0)
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
            
            // 左上角状态指示器
            VStack(alignment: .leading, spacing: 4) {
                // 上传中状态
                if item.isUploading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Uploading...")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                }
                
                // 上传失败状态
                if item.uploadFailed {
                    HStack(spacing: 4) {
                        Text("⚠️")
                            .font(.system(size: 10))
                        Text("Failed")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(4)
                }
            }
            .padding(6)
            
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
                Button(action: onRetry) {
                    Text("↻")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.red.opacity(0.8))
            .cornerRadius(4)
            .offset(x: -4, y: -4)
        }
    }
    
    // MARK: - Bookmark Button
    
    private var bookmarkButton: some View {
        Button(action: onToggleBookmark) {
            Text(item.isBookmarked ? "❤" : "♡")
                .font(.system(size: item.isBookmarked ? 15 : 18))
                .foregroundColor(item.isBookmarked ? Theme.delete : Theme.textSecondary)
        }
        .buttonStyle(.plain)
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
                .help("View Image")
            }
            
            Button(action: onDelete) {
                Text("🗑")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.delete)
            }
            .buttonStyle(.plain)
            .help("Delete")
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

