# Pastee macOS 安装程序构建指南

本目录包含构建 Pastee macOS PKG 安装程序所需的所有文件。

## 目录结构

```
installer/
├── build-installer.sh    # 主构建脚本
├── Distribution.xml      # PKG 安装配置
├── README.md            # 本文档
├── scripts/
│   ├── preinstall       # 安装前脚本（退出运行中的 Pastee）
│   └── postinstall      # 安装后脚本
├── build/               # 构建临时目录（自动生成）
└── dist/                # 输出目录（自动生成）
```

## 前置要求

1. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **Apple Developer 账户**（用于签名和公证）
   - Developer ID Application 证书
   - Developer ID Installer 证书

## 快速开始

### 仅构建（不签名）

适用于本地测试：

```bash
cd macos/installer
./build-installer.sh
```

输出: `dist/Pastee-{版本号}.pkg`

### 构建并签名

```bash
./build-installer.sh --sign \
    --dev-id "Developer ID Application: Your Name (TEAMID)" \
    --installer-id "Developer ID Installer: Your Name (TEAMID)"
```

### 构建、签名并公证

#### 方式 1: 使用 Keychain Profile（推荐）

首次设置凭据（只需执行一次）：

```bash
xcrun notarytool store-credentials "pastee-notary" \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

> 注意: password 是 App-specific password，需要在 https://appleid.apple.com 生成

构建命令：

```bash
./build-installer.sh --sign --notarize \
    --dev-id "Developer ID Application: Your Name (TEAMID)" \
    --installer-id "Developer ID Installer: Your Name (TEAMID)" \
    --keychain-profile "pastee-notary"
```

#### 方式 2: 直接使用凭据

```bash
./build-installer.sh --sign --notarize \
    --dev-id "Developer ID Application: Your Name (TEAMID)" \
    --installer-id "Developer ID Installer: Your Name (TEAMID)" \
    --apple-id "your@email.com" \
    --team-id "TEAMID" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

## 构建选项

| 选项 | 说明 |
|------|------|
| `--sign` | 签名应用和安装包 |
| `--notarize` | 公证安装包（需要 `--sign`） |
| `--dev-id <ID>` | Developer ID Application 证书名称 |
| `--installer-id <ID>` | Developer ID Installer 证书名称 |
| `--apple-id <ID>` | Apple ID（用于公证） |
| `--team-id <ID>` | Team ID（用于公证） |
| `--password <PWD>` | App-specific password |
| `--keychain-profile <NAME>` | Keychain 存储的凭据配置文件名 |
| `--arch <ARCH>` | 构建架构: `universal`(默认), `arm64`, `x86_64` |
| `--help` | 显示帮助信息 |

## 获取签名证书信息

查看可用的签名证书：

```bash
# 列出所有可用的 Developer ID 证书
security find-identity -v -p codesigning

# 列出安装程序签名证书
security find-identity -v -p basic
```

输出示例：
```
1) ABCD1234... "Developer ID Application: Your Name (TEAMID)"
2) EFGH5678... "Developer ID Installer: Your Name (TEAMID)"
```

## 获取 Team ID

Team ID 可以从以下位置获取：
1. Apple Developer 网站 → Membership → Team ID
2. 或从证书名称中获取（括号内的字符串）

## 公证流程说明

1. **提交** - 将签名的 PKG 上传到 Apple 公证服务
2. **等待** - Apple 自动扫描恶意软件（通常几分钟）
3. **Staple** - 将公证票据附加到 PKG 文件

公证后的安装包可以在任何 Mac 上双击安装，无需在"安全性与隐私"中手动允许。

## 安装包功能

- **双击安装**: 用户双击 PKG 文件即可启动安装向导
- **自动退出旧版本**: 安装前自动退出正在运行的 Pastee
- **安装到 /Applications**: 应用安装到标准应用程序目录
- **签名验证**: macOS Gatekeeper 验证签名
- **公证验证**: Apple 恶意软件扫描验证

## 故障排除

### 签名失败

```
Error: The specified item could not be found in the keychain.
```

解决方案：确保证书已导入到 Keychain，并且名称完全匹配。

### 公证失败

检查公证日志：

```bash
xcrun notarytool log <submission-id> --keychain-profile "pastee-notary"
```

常见问题：
- 应用未启用 Hardened Runtime
- 包含未签名的二进制文件
- 使用了不允许的权限

### 验证安装包

```bash
# 验证签名
pkgutil --check-signature dist/Pastee-*.pkg

# 验证公证
spctl --assess --type install dist/Pastee-*.pkg
xcrun stapler validate dist/Pastee-*.pkg
```

## 自动化 CI/CD

可以在 GitHub Actions 或其他 CI 中使用此脚本：

```yaml
- name: Build and Notarize
  env:
    DEVELOPER_ID: ${{ secrets.DEVELOPER_ID }}
    INSTALLER_ID: ${{ secrets.INSTALLER_ID }}
    APPLE_ID: ${{ secrets.APPLE_ID }}
    TEAM_ID: ${{ secrets.TEAM_ID }}
    APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
  run: |
    ./macos/installer/build-installer.sh --sign --notarize \
      --dev-id "$DEVELOPER_ID" \
      --installer-id "$INSTALLER_ID" \
      --apple-id "$APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$APP_PASSWORD"
```

