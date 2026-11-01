#!/usr/bin/env bash
set -euo pipefail

# Build AppImage for Daftari
# Usage: ./build-appimage.sh [version]

VERSION="${1:-$(git describe --tags --always --dirty)}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APP_DIR="${PROJECT_ROOT}/apps/daftari"
BUILD_DIR="${APP_DIR}/build/linux/x64/release/bundle"
APPDIR="${PROJECT_ROOT}/build/appimage/daftari.AppDir"
OUTPUT_DIR="${PROJECT_ROOT}/build/appimage/output"

echo "Building AppImage v${VERSION}..."

# 1. Flutter Linux release build
cd "${APP_DIR}"
flutter build linux --release --dart-define=ED25519_PUBKEY_HEX="${ED25519_PUBKEY_HEX}"

# 2. Build PrintServer.Linux (self-contained)
cd "${PROJECT_ROOT}/PrintServer.Linux"
echo "Publishing PrintServer.Linux to ${BUILD_DIR}/PrintServer..."
dotnet publish PrintServer.Linux.csproj -c Release -r linux-x64 --self-contained true -o "${BUILD_DIR}/PrintServer" -v d 2>&1 | tail -50
echo "dotnet publish exit code: ${PIPESTATUS[0]}"
ls -la "${BUILD_DIR}/PrintServer/"

# 3. Create AppDir with linuxdeploy
echo "Creating AppDir..."
mkdir -p "${APPDIR}/usr/share/daftari"
cd "${PROJECT_ROOT}"

# Copy Flutter bundle
echo "Copying Flutter bundle..."
cp -r "${BUILD_DIR}/"* "${APPDIR}/usr/share/daftari/"
echo "cp exit code: $?"

# Rename binary to match expected name (flutter uses underscore, we want dash).
# No-op removed: Flutter already emits the dash-named binary; the mv source==dest
# was a no-op. Keep this step documented in case the bundle naming changes.
echo "Binary name check: $(ls "${APPDIR}/usr/share/daftari/" | head -5)"

# Desktop entry
echo "Copying desktop file..."
cp "${PROJECT_ROOT}/packaging/linux/AppImage/daftari.desktop" "${APPDIR}/daftari.desktop"
echo "cp desktop exit code: $?"

# Icon
echo "Copying icon..."
cp "${PROJECT_ROOT}/packaging/linux/AppImage/daftari.png" "${APPDIR}/daftari.png"
echo "cp icon exit code: $?"

# AppRun entry point (linuxdeploy generates this, but we customize)
echo "Creating AppRun..."
cat > "${APPDIR}/AppRun" <<'EOF'
#!/usr/bin/env bash
# AppRun - Entry point for AppImage
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
export PATH="${HERE}/usr/bin:${PATH}"

# Ensure PrintServer.Linux is executable
chmod +x "${HERE}/usr/share/daftari/PrintServer/PrintServer.Linux"

# Set up font config for Arabic rendering
export FONTCONFIG_PATH="${HERE}/usr/share/daftari/PrintServer/Assets:${FONTCONFIG_PATH}"

# Launch Flutter app
exec "${HERE}/usr/share/daftari/daftari" "$@"
EOF
chmod +x "${APPDIR}/AppRun"
echo "AppRun created"

# 4. Run linuxdeploy to bundle dependencies
# Try to install GTK plugin via apt first
echo "Installing GTK plugin via apt..."
sudo apt-get update && sudo apt-get install -y linuxdeploy-plugin-gtk || echo "GTK plugin not available via apt, continuing without it"

echo "Running linuxdeploy..."
linuxdeploy \
  --appdir "${APPDIR}" \
  --executable "${APPDIR}/usr/share/daftari/daftari" \
  --desktop-file "${APPDIR}/daftari.desktop" \
  --icon-file "${APPDIR}/daftari.png" \
  --output appimage
echo "linuxdeploy exit code: $?"

# 5. Move result
mkdir -p "${OUTPUT_DIR}"
mapfile -t APPIMAGE_FILES < <(find . -maxdepth 1 -name "*.AppImage" -type f -print)
if [[ "${#APPIMAGE_FILES[@]}" -eq 0 ]]; then
  echo "No AppImage was produced by linuxdeploy" >&2
  exit 1
fi
if [[ "${#APPIMAGE_FILES[@]}" -gt 1 ]]; then
  echo "Multiple AppImages were produced; refusing to choose implicitly:" >&2
  printf '  %s\n' "${APPIMAGE_FILES[@]}" >&2
  exit 1
fi
mv "${APPIMAGE_FILES[0]}" "${OUTPUT_DIR}/daftari-${VERSION}-linux-x86_64.AppImage"

echo "AppImage created: ${OUTPUT_DIR}/daftari-${VERSION}-linux-x86_64.AppImage"
