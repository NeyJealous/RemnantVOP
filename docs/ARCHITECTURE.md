# RemnantVOP architecture

## Goal

One iOS application and one `NEPacketTunnelProvider` extension expose three protocol families through a common profile, subscription and routing layer.

```text
SwiftUI App
   |
   +-- ProfileImporter
   |     +-- vpn:// -> Amnezia JSON -> AWG profile
   |     +-- vless:// -> VLESS profile
   |     +-- hysteria2:// / hy2:// -> Hysteria2 profile
   |     +-- https:// -> Subscription
   |
   +-- VPNProfile
   |     +-- RoutingProfile
   |
   +-- NETunnelProviderManager
              |
              v
      PacketTunnelProvider
              |
      +-------+---------+
      |                 |
   AWGEngine        SingBoxEngine
      |             /           \
amneziawg-apple  VLESS        Hysteria2
```

## Design constraints

### One Packet Tunnel extension

Only one engine is active for a selected profile at a time. This keeps iOS VPN state and lifecycle in one place.

### Raw configuration preservation

Imported configuration is preserved as raw source data inside `VPNProfile`.

This matters most for Amnezia `vpn://` keys. AWG 3.x evolves independently of the UI and an import/export cycle must not silently delete fields that a parser does not yet understand.

### Shared routing model

The UI edits one `RoutingProfile`.

Later compilers convert it differently:

- VLESS/Hysteria2: domains, CIDRs and remote rule-sets become sing-box route rules.
- AWG: IP/CIDR rules become NetworkExtension/WireGuard routes; domain rules require DNS resolution or generated CIDR/rule data.

### Fail closed

The Phase 0 adapters throw `coreNotLinked`. A profile must never report a successful VPN connection before its protocol engine actually starts.

## vpn:// compatibility

Current Amnezia clients encode connection keys as URL-safe Base64 containing qCompress/zlib data. qCompress normally prepends a four-byte big-endian uncompressed length.

Some Amnezia API-generated keys replace that length with the signature `00 00 00 ff`. The decoder treats that value as a signature rather than a trustworthy output length and expands the zlib output buffer dynamically.

## Planned phases

### Phase 1 — AWG 3.1
- link amneziawg-apple
- map current AWG 3.1 fields
- connect/disconnect on a real iPhone
- import both .conf and vpn:// without field loss

### Phase 2 — sing-box
- build/link sing-box for iOS
- VLESS
- Hysteria2
- shared sing-box routing compiler
- DNS policy

### Phase 3 — subscriptions
- Remnawave HTTPS subscription
- Base64/text subscriptions
- refresh metadata and expiry
- atomic profile updates

### Phase 4 — routing
- full tunnel
- VPN only for matching rules
- bypass matching rules
- remote rule-set refresh
- AWG CIDR aggregation

### Phase 5 — distribution
- GitHub Actions archive
- unsigned IPA artifact
- optional certificate signing path
