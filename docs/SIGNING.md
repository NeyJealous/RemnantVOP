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

## Download automatic test releases

On each successful push / manual run of the iOS build workflow (not pull requests), a separate least-privileged publishing job:

1. downloads the verified Actions build artifact;
2. checks SHA-256, IPA ZIP integrity and the presence of all three Packet Tunnel extensions;
3. creates a uniquely tagged **GitHub prerelease** with the unsigned IPA, `SHA256SUMS.txt` and this signing guide.

Go to [GitHub Releases](https://github.com/NeyJealous/RemnantVOP/releases) and download the newest test build for your branch. If the repository is private, sign in to GitHub first.

**Do not upload a .p12, private signing key or provisioning profile to this CI.** Signing remains local. A passed build does not guarantee working network connectivity on a physical device.
