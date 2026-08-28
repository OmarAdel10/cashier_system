#!/usr/bin/env bash
set -euo pipefail

# Build AppImage for Cashier System
# Usage: ./build-appimage.sh [version]

VERSION="${1:-$(git describe --tags --always --dirty)}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/linux/x64/release/bundle"
APPDIR="${PROJECT_ROOT}/build/appimage/cashier-system.AppDir"
OUTPUT_DIR="${PROJECT_ROOT}/build/appimage/output"

echo "Building AppImage v${VERSION}..."

# 1. Flutter Linux release build
cd "${PROJECT_ROOT}"
flutter build linux --release --dart-define=ED25519_PUBKEY_HEX="${ED25519_PUBKEY_HEX}"

# 2. Build PrintServer.Linux (self-contained)
cd "${PROJECT_ROOT}/PrintServer.Linux"
dotnet publish PrintServer.Linux.csproj -c Release -r linux-x64 --self-contained true -o "${BUILD_DIR}/PrintServer"

# 3. Create AppDir with linuxdeploy
mkdir -p "${APPDIR}/usr/share/cashier-system"
cd "${PROJECT_ROOT}"

# Copy Flutter bundle
cp -r "${BUILD_DIR}/"* "${APPDIR}/usr/share/cashier-system/"

# Rename binary to match expected name (flutter uses underscore, we want dash)
mv "${APPDIR}/usr/share/cashier-system/cashier_system" "${APPDIR}/usr/share/cashier-system/cashier-system"

# Desktop entry
cp "${PROJECT_ROOT}/packaging/linux/AppImage/cashier-system.desktop" "${APPDIR}/cashier-system.desktop"

# Icon
cp "${PROJECT_ROOT}/packaging/linux/AppImage/cashier-system.png" "${APPDIR}/cashier-system.png"

# AppRun entry point (linuxdeploy generates this, but we customize)
cat > "${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
# AppRun - Entry point for AppImage
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export PATH="${HERE}/usr/bin:${PATH}"

# Ensure PrintServer.Linux is executable
chmod +x "${HERE}/usr/share/cashier-system/PrintServer/PrintServer.Linux"

# Set up font config for Arabic rendering
export FONTCONFIG_PATH="${HERE}/usr/share/cashier-system/PrintServer/Assets:${FONTCONFIG_PATH}"

# Launch Flutter app
exec "${HERE}/usr/share/cashier-system/cashier-system" "$@"
EOF
chmod +x "${APPDIR}/AppRun"

# 4. Run linuxdeploy to bundle dependencies
linuxdeploy \
  --appdir "${APPDIR}" \
  --executable "${APPDIR}/usr/share/cashier-system/cashier-system" \
  --desktop-file "${APPDIR}/cashier-system.desktop" \
  --icon-file "${APPDIR}/cashier-system.png" \
  --output appimage \
  --plugin gtk

# 5. Move result
mkdir -p "${OUTPUT_DIR}"
mv "${PROJECT_ROOT}"/Cashier-System-*.AppImage "${OUTPUT_DIR}/Cashier-System-${VERSION}-linux-x86_64.AppImage"

echo "AppImage created: ${OUTPUT_DIR}/Cashier-System-${VERSION}-linux-x86_64.AppImage"