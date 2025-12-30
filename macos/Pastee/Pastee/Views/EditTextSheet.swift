//
//  EditTextSheet.swift
//  Pastee
//
//  编辑文本对话框
//

import SwiftUI
import AppKit

struct EditTextSheet: View {
    @State private var text: String
    @State private var shouldFocus = false
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    init(content: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        _text = State(initialValue: content)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit clipboard content:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 10)
            
            FocusableTextEditor(
                text: $text,
                shouldFocus: $shouldFocus
            )
            .frame(minHeight: 180, maxHeight: 300)
            .background(Theme.surface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.accent.opacity(0.5), lineWidth: 2)
            )
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(LinkButtonStyle())
                .padding(.trailing, 10)
                
                Button("Save") {
                    onSave(text)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.top, 20)
        }
        .padding(20)
        .frame(width: 450)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accent.opacity(0.6), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                shouldFocus = true
            }
        }
    }
}

// MARK: - FocusableTextEditor

struct FocusableTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var shouldFocus: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = NSColor(Theme.textPrimary)
        textView.backgroundColor = NSColor(Theme.surface)
        textView.insertionPointColor = NSColor(Theme.textPrimary)
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor(Theme.surface)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        
        if textView.string != text {
            textView.string = text
        }
        
        if shouldFocus {
            DispatchQueue.main.async {
                if let window = nsView.window {
                    window.makeFirstResponder(textView)
                }
                shouldFocus = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FocusableTextEditor
        
        init(_ parent: FocusableTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                parent.text = textView.string
            }
        }
    }
}

// MARK: - CategoryInputSheet

struct CategoryInputSheet: View {
    @Binding var isPresented: Bool
    @State private var categoryName = ""
    let onSave: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Category Name:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .padding(.bottom, 10)
            
            TextField("", text: $categoryName)
                .textFieldStyle(CustomTextFieldStyle())
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(LinkButtonStyle())
                
                Button("Save") {
                    if !categoryName.isEmpty {
                        onSave(categoryName)
                        isPresented = false
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.top, 20)
        }
        .padding(20)
        .frame(width: 350)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
}

// MARK: - ConfirmDialog

struct ConfirmDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .padding(.bottom, 15)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(LinkButtonStyle())
                .padding(.trailing, 15)
                
                Button(confirmTitle) {
                    onConfirm()
                }
                .buttonStyle(DeleteButtonStyle())
            }
            .padding(.top, 20)
        }
        .padding(25)
        .frame(width: 400)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        EditTextSheet(
            content: "Test content",
            onSave: { _ in },
            onCancel: {}
        )
        
        ConfirmDialog(
            title: "Confirm Action",
            message: "Are you sure you want to delete this item?",
            confirmTitle: "Delete",
            onConfirm: {},
            onCancel: {}
        )
    }
    .padding()
    .background(Color.black)
}

