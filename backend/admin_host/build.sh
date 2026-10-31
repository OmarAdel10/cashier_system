#!/bin/bash
set -e

# Build the admin WASM bundle and copy it into public/ for deploy.
OUT_DIR="public"

# Resolve source directory: prefer the standard flutter build output relative
# to this script, but also support the monorepo layout where this script runs
# from backend/admin_host/ and the root is three levels up.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Candidates in priority order
CANDIDATES=(
  "$SCRIPT_DIR/../../build/web"           # standard: repo_root/build/web
  "$ROOT_DIR/build/web"                   # explicit root reference
)

SRC=""
for c in "${CANDIDATES[@]}"; do
  if [ -d "$c" ]; then
    SRC="$c"
    break
  fi
done

if [ -z "$SRC" ]; then
  echo "ERROR: run 'flutter build web' first (FLAVOR=admin ENV=production)"
  echo "Checked candidates:"
  for c in "${CANDIDATES[@]}"; do
    echo "  $c"
  done
  exit 1
fi

mkdir -p "$OUT_DIR"
cp -r "$SRC"/* "$OUT_DIR/"
# Copy .assetsignore into public/ so Wrangler excludes dotfiles/hidden files
# from the deployed asset bundle (DAFTARI-145).
if [ -f "$SCRIPT_DIR/.assetsignore" ]; then
  cp "$SCRIPT_DIR/.assetsignore" "$OUT_DIR/"
fi
echo "Admin WASM build copied to $OUT_DIR/ (from $SRC)"
ls "$OUT_DIR/" | head -5
