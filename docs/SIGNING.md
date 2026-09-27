# Signing Remnant VPN

The GitHub Actions release workflow creates an **unsigned** iOS IPA. The application contains three Packet Tunnel extensions:

- `com.neyjealous.RemnantVOP.AWGTunnel`
- `com.neyjealous.RemnantVOP.HysteriaTunnel`
- `com.neyjealous.RemnantVOP.XrayTunnel`

The main app bundle is `com.neyjealous.RemnantVOP`.

## Required Apple capabilities

The provisioning used for the main app and all three extensions must allow:

- Network Extensions → Packet Tunnel Provider
- App Groups → `group.com.neyjealous.RemnantVOP`

A certificate alone is not enough. The provisioning profile must contain the matching entitlements and bundle identifier.

## Sideload signing

When signing the IPA with KSign or another recursive iOS signer, verify that the signer signs all embedded `.appex` bundles before signing the main application and preserves their Network Extension entitlements.

If your provisioning profiles use different bundle identifiers, change the four bundle identifiers and the App Group consistently in `project.yml`, `VPNProviderDescriptor.swift`, and the entitlement files before building.
