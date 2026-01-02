#!/bin/bash
# ============================================================
# Pastee macOS Installer Builder
# 构建、签名、公证 macOS 安装程序
# ============================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XCODE_PROJECT="$PROJECT_DIR/Pastee/Pastee.xcodeproj"
APP_NAME="Pastee"
BUNDLE_ID="im.pastee.app"
INSTALLER_BUNDLE_ID="im.pastee.installer"

# 输出目录
BUILD_DIR="$SCRIPT_DIR/build"
DIST_DIR="$SCRIPT_DIR/dist"
PAYLOAD_DIR="$BUILD_DIR/payload"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# 从 Info.plist 读取版本号
INFO_PLIST="$PROJECT_DIR/Pastee/Pastee/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0.0")

# ============================================================
# 帮助信息
# ============================================================
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --sign              签名应用和安装包"
    echo "  --notarize          公证安装包（需要 --sign）"
    echo "  --dev-id <ID>       开发者 ID（用于签名）"
    echo "  --installer-id <ID> 安装程序开发者 ID（用于签名 PKG）"
    echo "  --apple-id <ID>     Apple ID（用于公证）"
    echo "  --team-id <ID>      Team ID（用于公证）"
    echo "  --password <PWD>    App-specific password（用于公证）"
    echo "  --keychain-profile  使用 Keychain 存储的公证凭据配置文件名"
    echo "  --arch <ARCH>       构建架构 (universal, arm64, x86_64)，默认 universal"
    echo "  --help              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  # 仅构建（不签名）"
    echo "  $0"
    echo ""
    echo "  # 构建并签名"
    echo "  $0 --sign --dev-id 'Developer ID Application: Your Name (TEAMID)' \\"
    echo "     --installer-id 'Developer ID Installer: Your Name (TEAMID)'"
    echo ""
    echo "  # 构建、签名并公证（使用 keychain profile）"
    echo "  $0 --sign --notarize \\"
    echo "     --dev-id 'Developer ID Application: Your Name (TEAMID)' \\"
    echo "     --installer-id 'Developer ID Installer: Your Name (TEAMID)' \\"
    echo "     --keychain-profile 'notary-profile'"
    echo ""
    echo "  # 首次设置公证凭据到 Keychain："
    echo "  xcrun notarytool store-credentials 'notary-profile' \\"
    echo "     --apple-id 'your@email.com' \\"
    echo "     --team-id 'TEAMID' \\"
    echo "     --password 'xxxx-xxxx-xxxx-xxxx'"
}

# ============================================================
# 参数解析
# ============================================================
SIGN=false
NOTARIZE=false
DEVELOPER_ID=""
INSTALLER_ID=""
APPLE_ID=""
TEAM_ID=""
APP_PASSWORD=""
KEYCHAIN_PROFILE=""
ARCH="universal"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN=true
            shift
            ;;
        --notarize)
            NOTARIZE=true
            shift
            ;;
        --dev-id)
            DEVELOPER_ID="$2"
            shift 2
            ;;
        --installer-id)
            INSTALLER_ID="$2"
            shift 2
            ;;
        --apple-id)
            APPLE_ID="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --password)
            APP_PASSWORD="$2"
            shift 2
            ;;
        --keychain-profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================
# 验证参数
# ============================================================
if $SIGN; then
    if [ -z "$DEVELOPER_ID" ]; then
        echo -e "${RED}错误: 签名需要 --dev-id 参数${NC}"
        exit 1
    fi
    if [ -z "$INSTALLER_ID" ]; then
        echo -e "${RED}错误: 签名需要 --installer-id 参数${NC}"
        exit 1
    fi
fi

if $NOTARIZE; then
    if ! $SIGN; then
        echo -e "${RED}错误: 公证需要先签名（--sign）${NC}"
        exit 1
    fi
    if [ -z "$KEYCHAIN_PROFILE" ]; then
        if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_PASSWORD" ]; then
            echo -e "${RED}错误: 公证需要 --keychain-profile 或 (--apple-id, --team-id, --password)${NC}"
            exit 1
        fi
    fi
fi

# ============================================================
# 日志函数
# ============================================================
log_step() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ============================================================
# 清理构建目录
# ============================================================
log_step "清理构建目录"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$DIST_DIR"
mkdir -p "$PAYLOAD_DIR/Applications"

log_success "构建目录已清理"

# ============================================================
# 构建应用
# ============================================================
log_step "构建 Pastee.app (架构: $ARCH)"

# 设置构建架构
case $ARCH in
    universal)
        ARCH_FLAGS="-arch arm64 -arch x86_64"
        ONLY_ACTIVE_ARCH="NO"
        ;;
    arm64)
        ARCH_FLAGS="-arch arm64"
        ONLY_ACTIVE_ARCH="YES"
        ;;
    x86_64)
        ARCH_FLAGS="-arch x86_64"
        ONLY_ACTIVE_ARCH="YES"
        ;;
    *)
        log_error "不支持的架构: $ARCH"
        exit 1
        ;;
esac

# 使用 xcodebuild 构建
xcodebuild -project "$XCODE_PROJECT" \
    -scheme "Pastee" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    ONLY_ACTIVE_ARCH="$ONLY_ACTIVE_ARCH" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build

# 找到构建的 app
BUILT_APP=$(find "$BUILD_DIR/DerivedData" -name "Pastee.app" -type d | head -1)

if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    log_error "找不到构建的应用"
    exit 1
fi

log_success "应用构建完成: $BUILT_APP"

# ============================================================
# 复制应用到 payload
# ============================================================
log_step "准备安装包内容"

cp -R "$BUILT_APP" "$PAYLOAD_DIR/Applications/"

log_success "应用已复制到 payload 目录"

# ============================================================
# 签名应用
# ============================================================
if $SIGN; then
    log_step "签名应用"
    
    APP_PATH="$PAYLOAD_DIR/Applications/Pastee.app"
    
    # 签名应用内的所有可执行文件和框架
    find "$APP_PATH" -type f -perm +111 -exec codesign --force --options runtime \
        --sign "$DEVELOPER_ID" \
        --timestamp \
        {} \; 2>/dev/null || true
    
    # 签名主应用
    codesign --force --options runtime \
        --sign "$DEVELOPER_ID" \
        --timestamp \
        --deep \
        "$APP_PATH"
    
    # 验证签名
    codesign --verify --verbose=2 "$APP_PATH"
    
    log_success "应用签名完成"
else
    log_warning "跳过应用签名（未指定 --sign）"
fi

# ============================================================
# 创建组件 PKG
# ============================================================
log_step "创建组件 PKG"

COMPONENT_PKG="$BUILD_DIR/Pastee.pkg"

pkgbuild \
    --root "$PAYLOAD_DIR" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "$SCRIPTS_DIR" \
    "$COMPONENT_PKG"

log_success "组件 PKG 创建完成"

# ============================================================
# 创建最终安装包
# ============================================================
log_step "创建最终安装包"

UNSIGNED_PKG="$BUILD_DIR/Pastee-$VERSION-unsigned.pkg"
FINAL_PKG="$DIST_DIR/Pastee-$VERSION.pkg"

# 使用 productbuild 创建最终安装包
productbuild \
    --distribution "$SCRIPT_DIR/Distribution.xml" \
    --package-path "$BUILD_DIR" \
    --version "$VERSION" \
    "$UNSIGNED_PKG"

log_success "安装包创建完成"

# ============================================================
# 签名安装包
# ============================================================
if $SIGN; then
    log_step "签名安装包"
    
    productsign \
        --sign "$INSTALLER_ID" \
        --timestamp \
        "$UNSIGNED_PKG" \
        "$FINAL_PKG"
    
    # 验证签名
    pkgutil --check-signature "$FINAL_PKG"
    
    log_success "安装包签名完成"
else
    # 未签名，直接复制
    cp "$UNSIGNED_PKG" "$FINAL_PKG"
    log_warning "安装包未签名"
fi

# ============================================================
# 公证
# ============================================================
if $NOTARIZE; then
    log_step "提交公证"
    
    if [ -n "$KEYCHAIN_PROFILE" ]; then
        # 使用 keychain profile
        xcrun notarytool submit "$FINAL_PKG" \
            --keychain-profile "$KEYCHAIN_PROFILE" \
            --wait
    else
        # 使用命令行参数
        xcrun notarytool submit "$FINAL_PKG" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_PASSWORD" \
            --wait
    fi
    
    log_success "公证提交完成"
    
    # Staple 公证票据
    log_step "Staple 公证票据"
    
    xcrun stapler staple "$FINAL_PKG"
    
    log_success "公证票据已 staple"
    
    # 验证
    xcrun stapler validate "$FINAL_PKG"
    
    log_success "公证验证通过"
else
    if $SIGN; then
        log_warning "跳过公证（未指定 --notarize）"
    fi
fi

# ============================================================
# 清理
# ============================================================
log_step "清理临时文件"

rm -rf "$BUILD_DIR/DerivedData"
rm -rf "$BUILD_DIR/payload"
rm -f "$BUILD_DIR/Pastee.pkg" 2>/dev/null || true
rm -f "$UNSIGNED_PKG" 2>/dev/null || true

log_success "清理完成"

# ============================================================
# 完成
# ============================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}构建完成！${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "安装包位置: $FINAL_PKG"
echo "版本: $VERSION"
echo "架构: $ARCH"
echo ""

if $SIGN; then
    echo "签名状态: ✓ 已签名"
else
    echo "签名状态: ✗ 未签名"
fi

if $NOTARIZE; then
    echo "公证状态: ✓ 已公证"
else
    echo "公证状态: ✗ 未公证"
fi

echo ""
echo "用户双击安装包即可安装 Pastee 到 /Applications 目录"

