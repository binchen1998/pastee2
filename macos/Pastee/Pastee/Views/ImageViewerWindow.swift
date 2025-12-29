//
//  ImageViewerWindow.swift
//  Pastee
//
//  图片查看器窗口
//

import SwiftUI
import AppKit

struct ImageViewerView: View {
    let imageData: Data?
    let title: String
    
    @State private var showToast = false
    
    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 头部
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: copyImage) {
                        Text("📋")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Copy to Clipboard")
                    
                    Button(action: { closeWindow() }) {
                        Text("✕")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(IconButtonStyle())
                    .help("Close (Esc)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // 图片容器
                ScrollView([.horizontal, .vertical]) {
                    if let data = imageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Text("Unable to load image")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(12)
                .background(Theme.surface)
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                
                // 图片信息
                if let data = imageData, let nsImage = NSImage(data: data) {
                    HStack {
                        Spacer()
                        Text("\(Int(nsImage.size.width)) × \(Int(nsImage.size.height)) • \(formatBytes(data.count))")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.background.opacity(0.8))
                            .cornerRadius(4)
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                    }
                }
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
                        .padding(.bottom, 30)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
    }
    
    private func copyImage() {
        guard let data = imageData, let image = NSImage(data: data) else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showToast = false
        }
    }
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// 创建图片查看器窗口
func showImageViewer(data: Data, title: String = "Image Viewer") {
    let view = ImageViewerView(imageData: data, title: title)
    
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
        styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.backgroundColor = .clear
    window.level = .floating
    window.center()
    window.contentView = NSHostingView(rootView: view)
    window.makeKeyAndOrderFront(nil)
}

// MARK: - Preview

#Preview {
    ImageViewerView(imageData: nil, title: "Image Viewer")
        .frame(width: 800, height: 600)
}

