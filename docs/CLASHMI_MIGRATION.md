# Remnant VPN — Clash Mi migration

## Decision

Remnant VPN keeps its own user-facing UX. Clash Mi is used as a proven technical reference/base for the Mihomo/iOS networking layer, subscription handling, DNS/routing concepts and lifecycle patterns.

The current native RC2 line remains intact as a fallback and comparison implementation.

## Product UX

Primary UI remains Remnant VPN:

- Home: one connect button, selected server, Auto/VLESS/Hysteria2/AWG 3.1.
- Servers: one physical server grouped with multiple available transports.
- Subscriptions: URL/import/update and grouping into servers.
- Routing: simple presets plus custom rules.
- DNS.
- Statistics.
- Settings and Diagnostics.

Advanced functionality adapted from Clash Mi is placed under an **Advanced** section rather than exposed on the main flow:

- providers / rule providers;
- raw Mihomo configuration;
- active connections;
- detailed logs;
- route/rule diagnostics;
- profile import/export.

## Core architecture

The UI should not expose process separation.

```text
Remnant VPN
  |
  +-- Mihomo tunnel
  |     +-- Hysteria2
  |     +-- optional compatibility transports
  |
  +-- Xray tunnel
  |     +-- VLESS
  |     +-- REALITY
  |     +-- Vision
  |     +-- XHTTP
  |
  +-- AmneziaWG tunnel
        +-- AWG 3.1
```

Only one Go runtime is loaded per Network Extension process.

## UI technology decision

Do **not** embed the existing SwiftUI hierarchy inside the Flutter runner.

Two viable implementations:

1. Reproduce the Remnant VPN design in Flutter while retaining Clash Mi's application infrastructure.
2. Keep the current SwiftUI app and selectively port only the native Mihomo/PacketTunnel layer.

For the migration branch, option 1 is the primary route because it preserves the largest amount of Clash Mi's mature subscription and application logic. The existing SwiftUI implementation remains the visual/behavioral specification.

## GPL

Clash Mi is GPL-3.0. Any copied or derived Clash Mi source stays under its applicable GPL terms. Keep its copyright/license notices. If a derived build is distributed, provide corresponding source as required by GPL-3.0.

## Migration gates

1. Freeze RC2 and preserve it as fallback.
2. Pin an exact Clash Mi upstream revision.
3. Reproduce a clean iOS build with its original PacketTunnel.
4. Rebrand bundle identifiers/assets without changing networking behavior.
5. Implement Remnant home/server/subscription UX.
6. Verify Hysteria2 and subscriptions on a physical iPhone.
7. Add isolated Xray extension.
8. Add isolated AWG 3.1 extension.
9. Add unified protocol Auto/fallback policy.
10. Port routing/DNS abstractions and diagnostics.
11. Device regression tests: connect, traffic, disconnect, reconnect, Wi-Fi/cellular change.
12. Produce unsigned IPA for personal signing.
