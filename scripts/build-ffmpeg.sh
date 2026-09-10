#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FFMPEG_VERSION="${FFMPEG_VERSION:-9.0.1}"
BUILD_ROOT="$PROJECT_ROOT/build/ffmpeg"
DOWNLOAD_ROOT="$PROJECT_ROOT/build/downloads"
TOOLS_ROOT="$PROJECT_ROOT/Resources/Tools"
ARCHIVE="$DOWNLOAD_ROOT/ffmpeg-$FFMPEG_VERSION.tar.xz"

mkdir -p "$BUILD_ROOT" "$DOWNLOAD_ROOT" "$TOOLS_ROOT"

if [[ ! -f "$ARCHIVE" ]]; then
    curl -fsSL "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.xz" -o "$ARCHIVE"
fi

build_arch() {
    local arch="$1"
    local source_dir="$BUILD_ROOT/source-$arch"
    local install_dir="$BUILD_ROOT/install-$arch"

    rm -rf "$source_dir" "$install_dir"
    mkdir -p "$source_dir" "$install_dir"
    tar -xf "$ARCHIVE" -C "$source_dir" --strip-components=1

    pushd "$source_dir" >/dev/null
    ./configure \
        --prefix="$install_dir" \
        --target-os=darwin \
        --arch="$arch" \
        --enable-cross-compile \
        --cc="xcrun --sdk macosx clang -arch $arch" \
        --extra-cflags="-mmacosx-version-min=13.0" \
        --extra-ldflags="-mmacosx-version-min=13.0" \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --disable-ffprobe \
        --disable-shared \
        --enable-static \
        --disable-autodetect \
        --disable-gpl \
        --disable-nonfree \
        --enable-securetransport \
        --enable-audiotoolbox \
        --enable-videotoolbox \
        --disable-x86asm
    make -j"$(sysctl -n hw.logicalcpu)" ffmpeg
    strip -x ffmpeg
    cp ffmpeg "$install_dir/"
    popd >/dev/null
}

build_arch arm64
build_arch x86_64

lipo -create \
    "$BUILD_ROOT/install-arm64/ffmpeg" \
    "$BUILD_ROOT/install-x86_64/ffmpeg" \
    -output "$TOOLS_ROOT/ffmpeg"

chmod +x "$TOOLS_ROOT/ffmpeg"
echo "Built universal FFmpeg $FFMPEG_VERSION tools."
