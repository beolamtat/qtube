#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_ROOT="$PROJECT_ROOT/dist"
BUILD_ROOT="$PROJECT_ROOT/build"
DMG_ROOT="$BUILD_ROOT/dmg-root"

package_arch() {
    local arch="$1"
    local app_source=""
    local dmg_name=""
    local vol_name=""

    local version
    version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_ROOT/Resources/Info.plist" 2>/dev/null || echo "1.0.2")"

    case "$arch" in
        arm64)
            "$PROJECT_ROOT/scripts/build-app.sh" arm64
            app_source="$DIST_ROOT/QTube-arm64.app"
            dmg_name="QTube-$version-AppleSilicon.dmg"
            vol_name="QTube (Apple Silicon)"
            ;;
        x86_64)
            "$PROJECT_ROOT/scripts/build-app.sh" x86_64
            app_source="$DIST_ROOT/QTube-x86_64.app"
            dmg_name="QTube-$version-Intel.dmg"
            vol_name="QTube (Intel)"
            ;;
        universal)
            "$PROJECT_ROOT/scripts/build-app.sh" universal
            app_source="$DIST_ROOT/QTube.app"
            dmg_name="QTube-$version-Universal.dmg"
            vol_name="QTube"
            ;;
    esac

    local dmg_path="$DIST_ROOT/$dmg_name"
    echo "=========================================="
    echo "Packaging DMG for $arch -> $dmg_path"
    echo "=========================================="

    rm -rf "$DMG_ROOT"
    mkdir -p "$DMG_ROOT"
    cp -R "$app_source" "$DMG_ROOT/QTube.app"
    cp "$PROJECT_ROOT/Resources/DMG-HUONG-DAN.txt" "$DMG_ROOT/HƯỚNG DẪN CÀI ĐẶT.txt"
    ln -s /Applications "$DMG_ROOT/Applications"

    rm -f "$dmg_path"
    hdiutil create \
        -volname "$vol_name" \
        -srcfolder "$DMG_ROOT" \
        -format UDZO \
        -ov \
        "$dmg_path"

    echo "Successfully created $dmg_path"
}

TARGET_ARCH="${1:-all}"
if [[ "$TARGET_ARCH" == "all" ]]; then
    package_arch arm64
    package_arch x86_64
elif [[ "$TARGET_ARCH" == "arm64" ]]; then
    package_arch arm64
elif [[ "$TARGET_ARCH" == "x86_64" ]]; then
    package_arch x86_64
elif [[ "$TARGET_ARCH" == "universal" ]]; then
    package_arch universal
else
    echo "Usage: $0 [arm64|x86_64|universal|all]" >&2
    exit 1
fi
