# Pastee for macOS

一个功能强大的剪贴板管理器，与 Windows 版本功能完全一致。

## 功能特性

- 📋 **剪贴板监控**: 自动捕获复制的文本和图片
- 🔄 **实时同步**: 通过 WebSocket 实现多设备实时同步
- 🔍 **快速搜索**: 搜索历史剪贴板内容
- ⭐ **收藏功能**: 收藏重要的剪贴板项目
- 📁 **分类管理**: 创建分类整理剪贴板内容
- ⌨️ **全局快捷键**: 自定义快捷键快速访问
- 🌙 **深色主题**: 现代化的深色 UI 设计

## 系统要求

- macOS 12.0 (Monterey) 或更高版本
- 支持 Intel 和 Apple Silicon

## 构建项目

1. 使用 Xcode 15.0+ 打开项目:
   ```bash
   open Pastee.xcodeproj
   ```

2. 选择目标设备 (My Mac)

3. 按 `Cmd + R` 运行项目

## 项目结构

```
Pastee/
├── PasteeApp.swift          # 应用入口
├── Info.plist               # 应用配置
├── Pastee.entitlements      # 权限配置
├── Models/                  # 数据模型
│   ├── ClipboardEntry.swift
│   ├── Category.swift
│   └── AppSettings.swift
├── Services/                # 核心服务
│   ├── APIService.swift     # API 网络请求
│   ├── AuthService.swift    # 认证服务
│   ├── WebSocketService.swift # WebSocket 实时同步
│   ├── ClipboardWatcher.swift # 剪贴板监控
│   ├── HotkeyService.swift  # 全局快捷键
│   ├── SettingsManager.swift # 设置管理
│   └── UpdateService.swift  # 自动更新
├── ViewModels/              # 视图模型
│   ├── MainViewModel.swift
│   └── LoginViewModel.swift
└── Views/                   # UI 视图
    ├── PopupWindow.swift    # 主弹窗窗口
    ├── ClipboardPopupView.swift # 主界面
    ├── LoginView.swift      # 登录界面
    ├── SettingsView.swift   # 设置界面
    ├── SearchView.swift     # 搜索界面
    ├── EditTextSheet.swift  # 编辑对话框
    ├── HotkeySettingsView.swift # 快捷键设置
    ├── ImageViewerWindow.swift # 图片查看器
    ├── UpdateView.swift     # 更新提示
    └── Components/          # UI 组件
        ├── ClipboardCardView.swift
        └── Theme.swift      # 主题颜色
```

## API 配置

应用连接到以下后端服务：
- API 基础 URL: `https://api.pastee-app.com`
- WebSocket URL: `wss://api.pastee-app.com/ws`

## 快捷键

默认快捷键: `Command + Shift + V`

可在设置中更改为以下预设:
- Command + Shift + V
- Ctrl + Shift + V
- Ctrl + Shift + C
- Ctrl + Alt + V
- Ctrl + Alt + C

## 本地存储

应用数据存储在:
```
~/Library/Application Support/Pastee/
├── auth.token          # JWT Token
├── device.id           # 设备 ID
├── settings.json       # 用户设置
├── clipboard.json      # 本地剪贴板缓存
└── images/             # 图片缓存
```

## 开发者

- 支持邮箱: binary.chen@gmail.com

## 许可证

Copyright © 2024 Pastee. All rights reserved.

