#!/bin/bash
set -e

# Build the admin WASM bundle and copy it into public/ for deploy.
OUT_DIR="public"

if [ -d ../../build/web ]; then
  SRC="../../build/web"
elif [ -d ../../../../CashierSystem/build/web ]; then
  SRC="../../../../CashierSystem/build/web"
else
  echo "ERROR: run 'flutter build web' first (FLAVOR=admin ENV=production)"
  exit 1
fi

mkdir -p "$OUT_DIR"
cp -r "$SRC"/* "$OUT_DIR/"
# Copy .assetsignore into public/ so Wrangler excludes dotfiles/hidden files
# from the deployed asset bundle (DAFTARI-145).
if [ -f "$(dirname "$0")/.assetsignore" ]; then
  cp "$(dirname "$0")/.assetsignore" "$OUT_DIR/"
fi
echo "Admin WASM build copied to $OUT_DIR/"
ls "$OUT_DIR/" | head -5
