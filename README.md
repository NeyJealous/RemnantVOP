# RemnantVOP

iOS VPN client for:

- AmneziaWG 3.1
- VLESS / Xray-compatible profiles
- Hysteria2
- `vpn://`, `vless://`, `hysteria2://`, `hy2://`
- HTTPS subscription URLs, including Remnawave
- shared routing profiles across all protocol engines

## Current status

### Phase 0 — complete

- SwiftUI application
- `NEPacketTunnelProvider`
- common `VPNProfile`
- common `RoutingProfile`
- import recognition
- Amnezia `vpn://` decoder

### Phase 1 — AmneziaWG 3.1

The AWG engine is connected to `amneziawg-apple` / `WireGuardKit`.

The parser supports the current AWG 3.1 fields:

```text
Jc Jmin Jmax
S1 S2 S3 S4
H1 H2 H3 H4
I1 I2 I3 I4 I5
HeaderProtectionKey
ContentPaddingAddition
RekeyAfterTime
RekeyTimeout
RejectAfterTime
KeepaliveTimeout
MaxHandshakeAttempts
RandomTrailers
DisableCookies
```

Both raw wg-quick/AWG configs and Amnezia `vpn://` JSON are accepted. Nested `last_config` data is searched recursively.

## Generate the Xcode project

```bash
brew install xcodegen
xcodegen generate
open RemnantVOP.xcodeproj
```

`WireGuardKit` requires the AmneziaWG Go bridge (`libwg-go.a`). The CI workflow shows the reproducible build command for iPhoneOS.

## Targets

- `RemnantVOP` — SwiftUI application
- `RemnantVOPPacketTunnel` — `NEPacketTunnelProvider`
- `RemnantVOPTests` — import/config tests

## Next

- validate AWG on a physical iPhone
- add `NETunnelProviderManager` connect/disconnect UI
- integrate sing-box for VLESS + Hysteria2
- implement subscription refresh and shared routing compilers
