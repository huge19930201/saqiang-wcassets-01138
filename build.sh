#!/bin/sh
set -eu
cd "$(dirname "$0")"
if ! command -v xcrun >/dev/null 2>&1; then
    echo '需要 macOS + Xcode 的 iPhoneOS SDK；当前未找到 xcrun。' >&2
    exit 1
fi
xcrun --sdk iphoneos --find clang >/dev/null
make "$@"
echo '构建产物：build/WCAssetsUI.dylib（未自动签名、安装或注入）'
