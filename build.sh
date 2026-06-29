#!/bin/bash
set -e

# Configuration
APP_NAME="ScreenPet"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"

echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR"

echo "📂 Creating App Bundle structure..."
mkdir -p "$MACOS_DIR"

echo "🛠️ Compiling Swift files..."
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)
swiftc -sdk "$SDK_PATH" -O Sources/*.swift -o "${MACOS_DIR}/${APP_NAME}"

echo "📋 Copying Info.plist..."
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

echo "✅ App bundle built successfully at: $(pwd)/${APP_BUNDLE}"
echo "🎉 To launch the app, run:"
echo "   open ${APP_BUNDLE}"
