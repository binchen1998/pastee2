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
            
            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .padding(10)
                .background(Theme.surface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.accent.opacity(0.5), lineWidth: 2)
                )
                .frame(minHeight: 180, maxHeight: 300)
            
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

