#!/bin/bash
echo "⚡ Starting EAS Build pre-install script..."

# 1. Install XcodeGen
echo "Installing XcodeGen via Homebrew..."
brew install xcodegen

# 2. Generate the Xcode project
echo "Generating Xcode project using XcodeGen..."
xcodegen generate

# 3. Create the symlink for EAS CLI to locate the iOS project
echo "Creating symlink for ios folder..."
ln -sf . ios

echo "✅ EAS pre-install script completed successfully!"
