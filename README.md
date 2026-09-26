# RemnantVOP

iOS VPN client foundation for a single application that will support:

- AmneziaWG 3.1
- VLESS / Xray-compatible profiles
- Hysteria2
- `vpn://`, `vless://`, `hysteria2://`, `hy2://`
- HTTPS subscription URLs, including Remnawave
- shared routing profiles across all protocol engines

## Current status

**Phase 0 — Foundation**

The repository contains a SwiftUI + NetworkExtension skeleton, a protocol-neutral profile model, routing model, import pipeline, `vpn://` decoder, and engine adapters prepared for AWG and sing-box integration.

The actual packet engines are intentionally not linked yet. `AWGEngine` and `SingBoxEngine` fail closed until their native cores are added in the next phases.

## Generate the Xcode project

The project definition is kept in `project.yml` and generated with XcodeGen:

```bash
brew install xcodegen
xcodegen generate
open RemnantVOP.xcodeproj
```

## Targets

- `RemnantVOP` — SwiftUI application
- `RemnantVOPPacketTunnel` — `NEPacketTunnelProvider` extension
- `RemnantVOPTests` — import/model tests

## Import formats

Phase 0 recognizes:

```text
vpn://...
vless://...
hysteria2://...
hy2://...
https://...
http://...
[Interface] / [Peer] AWG-WireGuard text
```

For Amnezia `vpn://` keys the original decoded JSON is preserved verbatim in the profile. This is deliberate: AWG 3.x fields unknown to the UI must not be discarded during import.

## Next phase

1. Link `amneziawg-apple` / WireGuardKit and implement `AWGEngine`.
2. Add the iOS sing-box library and implement VLESS + Hysteria2 in `SingBoxEngine`.
3. Add `NETunnelProviderManager` persistence/connect controls.
4. Add Remnawave subscription fetching and refresh.
5. Compile the shared routing model into sing-box rules and AWG IP routes.
