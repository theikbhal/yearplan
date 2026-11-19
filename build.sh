#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/YearPlan.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp .build/release/YearPlan "$APP/Contents/MacOS/YearPlan"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>YearPlan</string>
<key>CFBundleExecutable</key><string>YearPlan</string>
<key>CFBundleIdentifier</key><string>com.ikbhal.yearplan</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
rm -rf /Applications/YearPlan.app
cp -R "$APP" /Applications/YearPlan.app
ln -sfn /Applications/YearPlan.app "$HOME/Desktop/YearPlan.app"
echo "Installed to /Applications and Desktop shortcut created."
open /Applications/YearPlan.app
