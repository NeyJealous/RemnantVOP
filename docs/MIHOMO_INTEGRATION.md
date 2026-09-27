# Mihomo iOS integration

Remnant VPN keeps its SwiftUI product UI and uses an isolated Mihomo Network Extension for Hysteria2.

## Upstream

The iOS bridge is built from the MIT-licensed ProxyCat source at:

- repository: MMitsuha/proxycat
- pinned revision: fd302ed10a76c4f81a5fcddf91a00200eaf6623e
- license: MIT
- embedded proxy core: MetaCubeX/mihomo (GPL-3.0)

The build script clones that exact revision and its pinned Mihomo submodule, then adds a small same-package Go adapter exposing StartWithYAML / ReloadWithYAML for Remnant's existing profile model.

## Process isolation

- AWG extension: AmneziaWG Go runtime only.
- Hysteria2 extension: Mihomo Go runtime only.
- Xray extension: libXray Go runtime only.
- Main app: no Go VPN core.

## iOS TUN contract

- iOS owns the utun descriptor.
- the descriptor is injected before Mihomo starts.
- Mihomo forces the gVisor stack.
- Mihomo auto-route, auto-redirect and auto-detect are disabled.
- NetworkExtension owns routes and DNS.
- IPv4 tunnel address: 198.18.0.1/16.
- IPv6 tunnel address: fd00:7f::1/64.
- tunnel DNS addresses: 198.18.0.2 and fd00:7f::2.
- Stop clears Mihomo runtime state and its cached fd.
- NWPath changes refresh Mihomo network state.

For the user this remains the Hysteria2 transport; Mihomo is an implementation detail.
