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
echo "Admin WASM build copied to $OUT_DIR/"
ls "$OUT_DIR/" | head -5
