#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AWG_CHECKOUT="${1:-}"

if [[ -z "$AWG_CHECKOUT" ]]; then
  if [[ -d "$PROJECT_ROOT/.spm/checkouts/amneziawg-apple" ]]; then
    AWG_CHECKOUT="$PROJECT_ROOT/.spm/checkouts/amneziawg-apple"
  else
    echo "Usage: $0 /path/to/amneziawg-apple"
    exit 1
  fi
fi

GO_DIR="$AWG_CHECKOUT/Sources/WireGuardKitGo"
test -d "$GO_DIR"

make -C "$GO_DIR" \
  ARCHS=arm64 \
  PLATFORM_NAME=iphoneos \
  SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)" \
  IPHONEOS_DEPLOYMENT_TARGET=16.0 \
  DEPLOYMENT_TARGET_CLANG_FLAG_NAME=miphoneos-version-min \
  DEPLOYMENT_TARGET_CLANG_ENV_NAME=IPHONEOS_DEPLOYMENT_TARGET

# amneziawg-apple currently passes "-L Sources/WireGuardKitGo/out" as a
# relative linker search path. In a consuming Xcode project that path is
# evaluated relative to PROJECT_DIR, not the package checkout.
LINKER_DIR="$PROJECT_ROOT/Sources/WireGuardKitGo/out"
mkdir -p "$LINKER_DIR"
cp "$GO_DIR/out/libwg-go.a" "$LINKER_DIR/libwg-go.a"

echo "AWG bridge ready: $LINKER_DIR/libwg-go.a"
