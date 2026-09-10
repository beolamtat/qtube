#!/bin/bash
set -euo pipefail

TARGET_ARCH="${1:-universal}"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ROOT="$PROJECT_ROOT/build"
DIST_ROOT="$PROJECT_ROOT/dist"
TOOLS_ROOT="$PROJECT_ROOT/Resources/Tools"
NOTICE_ROOT="$PROJECT_ROOT/Resources/ThirdPartyNotices/generated"
MODULE_CACHE="$PROJECT_ROOT/.build/module-cache"

case "$TARGET_ARCH" in
    arm64)
        APP_BUNDLE="$DIST_ROOT/QTube-arm64.app"
        SWIFT_ARCH_FLAGS=("--arch" "arm64")
        ;;
    x86_64)
        APP_BUNDLE="$DIST_ROOT/QTube-x86_64.app"
        SWIFT_ARCH_FLAGS=("--arch" "x86_64")
        ;;
    universal)
        APP_BUNDLE="$DIST_ROOT/QTube.app"
        SWIFT_ARCH_FLAGS=("--arch" "arm64" "--arch" "x86_64")
        ;;
    *)
        echo "Unknown architecture: $TARGET_ARCH. Use arm64, x86_64, or universal." >&2
        exit 1
        ;;
esac

for tool in yt-dlp_macos ffmpeg quickjs; do
    if [[ ! -x "$TOOLS_ROOT/$tool" ]]; then
        echo "Missing Resources/Tools/$tool. Run scripts/fetch-tools.sh first." >&2
        exit 1
    fi
done

mkdir -p "$BUILD_ROOT" "$DIST_ROOT" "$MODULE_CACHE"

export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"

swift build \
    --disable-sandbox \
    --configuration release \
    "${SWIFT_ARCH_FLAGS[@]}" \
    --cache-path "$PROJECT_ROOT/.build/cache" \
    --config-path "$PROJECT_ROOT/.build/config" \
    --security-path "$PROJECT_ROOT/.build/security"

BIN_PATH="$(swift build \
    --disable-sandbox \
    --configuration release \
    "${SWIFT_ARCH_FLAGS[@]}" \
    --show-bin-path \
    --cache-path "$PROJECT_ROOT/.build/cache" \
    --config-path "$PROJECT_ROOT/.build/config" \
    --security-path "$PROJECT_ROOT/.build/security")"

rm -rf "$APP_BUNDLE"
mkdir -p \
    "$APP_BUNDLE/Contents/MacOS" \
    "$APP_BUNDLE/Contents/Resources/Tools" \
    "$APP_BUNDLE/Contents/Resources/ThirdPartyNotices"

cp "$BIN_PATH/QTube" "$APP_BUNDLE/Contents/MacOS/QTube"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

for tool in ffmpeg quickjs; do
    if [[ "$TARGET_ARCH" == "universal" ]]; then
        cp "$TOOLS_ROOT/$tool" "$APP_BUNDLE/Contents/Resources/Tools/$tool"
    else
        lipo "$TOOLS_ROOT/$tool" -thin "$TARGET_ARCH" -output "$APP_BUNDLE/Contents/Resources/Tools/$tool"
    fi
done

# yt-dlp_macos là nhị phân universal PyInstaller chứa PKG archive đính ở đuôi file.
# Không dùng lipo -thin vì lipo sẽ cắt mất gói archive khiến app báo lỗi PyInstaller.
cp "$TOOLS_ROOT/yt-dlp_macos" "$APP_BUNDLE/Contents/Resources/Tools/yt-dlp_macos"

cp "$PROJECT_ROOT/Resources/ThirdPartyNotices/COMPONENTS.txt" \
    "$APP_BUNDLE/Contents/Resources/ThirdPartyNotices/"
cp -R "$NOTICE_ROOT/." "$APP_BUNDLE/Contents/Resources/ThirdPartyNotices/"

ICON_SOURCE="$PROJECT_ROOT/Resources/AppIcon.png"
if [[ ! -f "$ICON_SOURCE" ]]; then
    ICON_SOURCE="$BUILD_ROOT/QTube-1024.png"
    xcrun swift "$PROJECT_ROOT/scripts/generate-icon.swift" "$ICON_SOURCE"
fi
ICONSET="$BUILD_ROOT/QTube.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    double_size=$((size * 2))
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$double_size" "$double_size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
xcrun swift "$PROJECT_ROOT/scripts/create-icns.swift" \
    "$ICONSET" \
    "$APP_BUNDLE/Contents/Resources/QTube.icns"
cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
sips -z 18 18 "$ICON_SOURCE" --out "$APP_BUNDLE/Contents/Resources/MenuBarIcon.png" >/dev/null
sips -z 36 36 "$ICON_SOURCE" --out "$APP_BUNDLE/Contents/Resources/MenuBarIcon@2x.png" >/dev/null
sips -z 54 54 "$ICON_SOURCE" --out "$APP_BUNDLE/Contents/Resources/MenuBarIcon@3x.png" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile QTube" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string QTube" "$APP_BUNDLE/Contents/Info.plist"

chmod +x "$APP_BUNDLE/Contents/MacOS/QTube" "$APP_BUNDLE/Contents/Resources/Tools/"*

for executable in quickjs ffmpeg yt-dlp_macos; do
    codesign --force --sign - --timestamp=none "$APP_BUNDLE/Contents/Resources/Tools/$executable"
done
codesign --force --sign - --timestamp=none "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
echo "Created $APP_BUNDLE ($TARGET_ARCH)"
