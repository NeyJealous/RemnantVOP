#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT/Vendor"
OUTPUT_DIR="$VENDOR_DIR/LibXray.xcframework"
VERSION="v26.9.9"
ARCHIVE="libxray-apple-cgo.zip"
SHA256="84a11f0923efb65be7631b3c4cac75bd4351fc13b9cc2394def6af5c1696e9fa"
URL="https://github.com/XTLS/libXray/releases/download/$VERSION/$ARCHIVE"

if [[ -d "$OUTPUT_DIR" ]]; then
  echo "LibXray already present: $OUTPUT_DIR"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl --fail --location --retry 3 "$URL" --output "$TMP_DIR/$ARCHIVE"
echo "$SHA256  $TMP_DIR/$ARCHIVE" | shasum -a 256 -c -

unzip -q "$TMP_DIR/$ARCHIVE" -d "$TMP_DIR/unpacked"
SOURCE="$TMP_DIR/unpacked/apple-cgo/LibXray.xcframework"

if [[ ! -d "$SOURCE" ]]; then
  echo "LibXray.xcframework not found in release archive"
  exit 1
fi

mkdir -p "$VENDOR_DIR"
cp -R "$SOURCE" "$OUTPUT_DIR"

echo "LibXray $VERSION ready: $OUTPUT_DIR"
