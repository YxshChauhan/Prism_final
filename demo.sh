#!/bin/bash

# AirLink Demo Script
# This script demonstrates the AirLink file transfer application

echo "🚀 AirLink Demo Script"
echo "======================"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter is installed: $(flutter --version | head -n 1)"
echo ""

# Check Flutter doctor
echo "🔍 Checking Flutter environment..."
flutter doctor
echo ""

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get
echo ""

# Generate code
echo "🔧 Generating code..."
flutter packages pub run build_runner build --delete-conflicting-outputs
echo ""

# Run tests
echo "🧪 Running tests..."
flutter test
echo ""

# Check for linting issues
echo "🔍 Checking for linting issues..."
flutter analyze
echo ""

# Build for different platforms
echo "🏗️  Building for different platforms..."
echo ""

# Android
echo "📱 Building Android APK..."
flutter build apk --release
if [ $? -eq 0 ]; then
    echo "✅ Android APK built successfully"
else
    echo "❌ Android APK build failed"
fi
echo ""

# iOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Building iOS app..."
    flutter build ios --release --no-codesign
    if [ $? -eq 0 ]; then
        echo "✅ iOS app built successfully"
    else
        echo "❌ iOS app build failed"
    fi
    echo ""
fi

# macOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "💻 Building macOS app..."
    flutter build macos --release
    if [ $? -eq 0 ]; then
        echo "✅ macOS app built successfully"
    else
        echo "❌ macOS app build failed"
    fi
    echo ""
fi

# Windows (if on Windows)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "🪟 Building Windows app..."
    flutter build windows --release
    if [ $? -eq 0 ]; then
        echo "✅ Windows app built successfully"
    else
        echo "❌ Windows app build failed"
    fi
    echo ""
fi

# Linux
echo "🐧 Building Linux app..."
flutter build linux --release
if [ $? -eq 0 ]; then
    echo "✅ Linux app built successfully"
else
    echo "❌ Linux app build failed"
fi
echo ""

echo "🎉 Demo completed!"
echo ""
echo "📋 Next steps:"
echo "1. Connect two devices to the same Wi-Fi network"
echo "2. Enable Bluetooth and Location services on both devices"
echo "3. Install AirLink on both devices"
echo "4. Open AirLink and tap 'Start Discovery'"
echo "5. Select a device and start transferring files!"
echo ""
echo "🔒 Security features:"
echo "- All transfers are encrypted with AES-GCM"
echo "- X25519 key exchange for secure key agreement"
echo "- No files are stored in plaintext during transfer"
echo ""
echo "📱 Supported platforms:"
echo "- Android (API 26+)"
echo "- iOS (12.0+)"
echo "- macOS (10.14+)"
echo "- Windows (10+)"
echo "- Linux (Ubuntu 18.04+)"
echo ""
echo "Happy transferring! 🚀"
