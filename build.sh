#!/usr/bin/env bash
# Build the GetWords desktop app (macOS / Linux).
# Produces a single-file executable in ./dist
set -e

cd "$(dirname "$0")"

echo ">> Installing dependencies..."
python3 -m pip install -r requirements.txt -r requirements-desktop.txt

echo ">> Building with PyInstaller..."
python3 -m PyInstaller getwords.spec --noconfirm --clean

echo ""
echo ">> Done. Your app is here:"
echo "   $(pwd)/dist/GetWords"
echo ""
echo "   Run it by double-clicking, or:  ./dist/GetWords"
