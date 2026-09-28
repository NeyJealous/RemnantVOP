#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKOUT="$ROOT/.deps/FlClash"
REV="c7be7023d33615cb624148d41414f80a7d96cede"

mkdir -p "$ROOT/.deps"

if [[ ! -d "$CHECKOUT/.git" ]]; then
  git clone --filter=blob:none --no-checkout https://github.com/chen08209/FlClash.git "$CHECKOUT"
fi

git -C "$CHECKOUT" fetch --depth=1 origin "$REV"
git -C "$CHECKOUT" checkout --force --detach "$REV"

# Upstream .gitmodules contains an SSH-only URL; CI uses the equivalent public HTTPS URL.
git -C "$CHECKOUT" config -f .gitmodules submodule.core/Clash.Meta.url   https://github.com/chen08209/Clash.Meta.git
git -C "$CHECKOUT" submodule sync --recursive
git -C "$CHECKOUT" submodule update --init --recursive --depth=1

python3 "$ROOT/scripts/patch-android-flclash.py" "$CHECKOUT"
printf '%s\n' "Android foundation: FlClash $REV with Remnant overlay at $CHECKOUT"
