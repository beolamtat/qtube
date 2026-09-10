#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOWNLOAD_ROOT="$PROJECT_ROOT/build/downloads"
TOOLS_ROOT="$PROJECT_ROOT/Resources/Tools"
NOTICE_ROOT="$PROJECT_ROOT/Resources/ThirdPartyNotices/generated"

mkdir -p "$DOWNLOAD_ROOT" "$TOOLS_ROOT" "$NOTICE_ROOT"

echo "Downloading the official yt-dlp macOS executable..."
curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" \
    -o "$TOOLS_ROOT/yt-dlp_macos"
curl -fsSL "https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS" \
    -o "$DOWNLOAD_ROOT/yt-dlp-SHA2-256SUMS"

expected_hash="$(awk '$2 == "yt-dlp_macos" { print $1 }' "$DOWNLOAD_ROOT/yt-dlp-SHA2-256SUMS")"
actual_hash="$(shasum -a 256 "$TOOLS_ROOT/yt-dlp_macos" | awk '{ print $1 }')"
if [[ -z "$expected_hash" || "$actual_hash" != "$expected_hash" ]]; then
    echo "yt-dlp checksum verification failed." >&2
    exit 1
fi
chmod +x "$TOOLS_ROOT/yt-dlp_macos"

curl -fsSL "https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/LICENSE" \
    -o "$NOTICE_ROOT/yt-dlp-LICENSE.txt"
curl -fsSL "https://raw.githubusercontent.com/yt-dlp/yt-dlp/master/THIRD_PARTY_LICENSES.txt" \
    -o "$NOTICE_ROOT/yt-dlp-THIRD_PARTY_LICENSES.txt"

echo "Downloading the official QuickJS JavaScript runtime..."
QUICKJS_VERSION="v0.16.2"
curl -fsSL "https://github.com/quickjs-ng/quickjs/releases/download/$QUICKJS_VERSION/qjs-darwin-arm64" \
    -o "$DOWNLOAD_ROOT/qjs-darwin-arm64"
curl -fsSL "https://github.com/quickjs-ng/quickjs/releases/download/$QUICKJS_VERSION/qjs-darwin-x86_64" \
    -o "$DOWNLOAD_ROOT/qjs-darwin-x86_64"

lipo -create \
    "$DOWNLOAD_ROOT/qjs-darwin-arm64" \
    "$DOWNLOAD_ROOT/qjs-darwin-x86_64" \
    -output "$TOOLS_ROOT/quickjs"
chmod +x "$TOOLS_ROOT/quickjs"
curl -fsSL "https://raw.githubusercontent.com/quickjs-ng/quickjs/master/LICENSE" \
    -o "$NOTICE_ROOT/quickjs-LICENSE.txt"

"$PROJECT_ROOT/scripts/build-ffmpeg.sh"

cp "$PROJECT_ROOT/build/ffmpeg/source-arm64/COPYING.LGPLv2.1" "$NOTICE_ROOT/ffmpeg-COPYING.LGPLv2.1.txt"
cp "$PROJECT_ROOT/build/ffmpeg/source-arm64/COPYING.LGPLv3" "$NOTICE_ROOT/ffmpeg-COPYING.LGPLv3.txt"

echo "All redistributable tools are ready."
