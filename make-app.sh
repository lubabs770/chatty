#!/bin/bash
# Build Chatty and wrap the binary in a proper .app bundle so macOS treats it
# as a real GUI app (key window + keyboard focus work).
#   ./make-app.sh                -> native-arch release build
#   UNIVERSAL=1 ./make-app.sh    -> universal (arm64 + x86_64) build
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="Chatty.app"
CONTENTS="${APP}/Contents"

ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "Building (${CONFIG}${UNIVERSAL:+ universal})..."
swift build -c "${CONFIG}" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c "${CONFIG}" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Chatty"

echo "Assembling ${APP}..."
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"
cp "${BIN}" "${CONTENTS}/MacOS/Chatty"
cp icon/AppIcon.icns "${CONTENTS}/Resources/AppIcon.icns"

cat > "${CONTENTS}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Chatty</string>
    <key>CFBundleDisplayName</key>     <string>Chatty</string>
    <key>CFBundleExecutable</key>      <string>Chatty</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>
    <key>CFBundleIdentifier</key>      <string>io.github.lubabs770.chatty</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

echo "Done: $(pwd)/${APP}"
echo "Launch with:  open \"$(pwd)/${APP}\""
