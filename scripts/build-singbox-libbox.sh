#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS_DIR="$ROOT/.deps"
SOURCE_DIR="$DEPS_DIR/sing-box"
OUTPUT_DIR="$ROOT/Vendor/Libbox.xcframework"

SING_BOX_VERSION="v1.14.1"
SING_BOX_COMMIT="1ac1a339cb1223e9c70eae14c44411c75033c02d"
GOMOBILE_VERSION="v0.1.13"

mkdir -p "$DEPS_DIR" "$ROOT/Vendor"

if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  git clone --filter=blob:none https://github.com/SagerNet/sing-box.git "$SOURCE_DIR"
fi

git -C "$SOURCE_DIR" fetch --force origin "$SING_BOX_COMMIT"
git -C "$SOURCE_DIR" checkout --detach "$SING_BOX_COMMIT"

actual_commit="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$SING_BOX_COMMIT" ]]; then
  echo "Unexpected sing-box commit: $actual_commit"
  exit 1
fi

export PATH="$(go env GOPATH)/bin:$PATH"
go install "github.com/sagernet/gomobile/cmd/gomobile@$GOMOBILE_VERSION"
go install "github.com/sagernet/gomobile/cmd/gobind@$GOMOBILE_VERSION"

pushd "$SOURCE_DIR" >/dev/null
rm -rf Libbox.xcframework
go run ./cmd/internal/build_libbox -target apple -platform ios
test -d Libbox.xcframework
popd >/dev/null

rm -rf "$OUTPUT_DIR"
cp -R "$SOURCE_DIR/Libbox.xcframework" "$OUTPUT_DIR"

echo "Libbox $SING_BOX_VERSION ($SING_BOX_COMMIT) ready: $OUTPUT_DIR"
