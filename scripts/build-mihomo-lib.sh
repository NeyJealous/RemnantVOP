#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROXYCAT_REV="fd302ed10a76c4f81a5fcddf91a00200eaf6623e"
PROXYCAT_DIR="$ROOT/.deps/proxycat"
OUT="$ROOT/Vendor/Libmihomo.xcframework"
XMOBILE_VERSION="v0.0.0-20260410095206-2cfb76559b7b"

mkdir -p "$ROOT/.deps" "$ROOT/Vendor"

if [[ ! -d "$PROXYCAT_DIR/.git" ]]; then
  git clone --filter=blob:none https://github.com/MMitsuha/proxycat.git "$PROXYCAT_DIR"
fi

git -C "$PROXYCAT_DIR" fetch --depth=1 origin "$PROXYCAT_REV"
git -C "$PROXYCAT_DIR" checkout --detach "$PROXYCAT_REV"
git -C "$PROXYCAT_DIR" submodule sync --recursive
git -C "$PROXYCAT_DIR" submodule update --init --recursive --depth=1

cat > "$PROXYCAT_DIR/libmihomo/remnant.go" <<'GOEOF'
package libmihomo

import (
    "fmt"

    "github.com/metacubex/mihomo/hub"
)

func StartRemnant(yamlConfig string) error {
    startMu.Lock()
    defer startMu.Unlock()

    if started.Load() {
        return fmt.Errorf("mihomo already started")
    }
    if yamlConfig == "" {
        return fmt.Errorf("mihomo config is empty")
    }

    cfg, err := prepareConfig(
        []byte(yamlConfig),
        RuntimeSettings{DisableExternalController: true},
    )
    if err != nil {
        return err
    }

    hub.ApplyConfig(cfg)
    startOOMKiller()
    started.Store(true)
    return nil
}

func ReloadRemnant(yamlConfig string) error {
    startMu.Lock()
    defer startMu.Unlock()

    if !started.Load() {
        return errMihomoNotStarted
    }
    if yamlConfig == "" {
        return fmt.Errorf("mihomo config is empty")
    }

    cfg, err := prepareConfig(
        []byte(yamlConfig),
        RuntimeSettings{DisableExternalController: true},
    )
    if err != nil {
        return err
    }

    hub.ApplyConfig(cfg)
    return nil
}
GOEOF

export PATH="$(go env GOPATH)/bin:$PATH"
go install "golang.org/x/mobile/cmd/gomobile@v0.0.0-20260410095206-2cfb76559b7b"
go install "golang.org/x/mobile/cmd/gobind@v0.0.0-20260410095206-2cfb76559b7b"
gomobile init

(
  cd "$PROXYCAT_DIR"
  GOMOBILE="$(command -v gomobile)" ./scripts/build-libmihomo.sh device
)

rm -rf "$OUT"
cp -R "$PROXYCAT_DIR/Frameworks/Libmihomo.xcframework" "$OUT"

echo "Built $OUT from ProxyCat $PROXYCAT_REV"
