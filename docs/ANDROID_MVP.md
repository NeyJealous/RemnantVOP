# Remnant VPN Android — networking-first plan

## Scope and status

The `android-mvp` branch keeps the iOS implementation unchanged and uses the
fully open-source FlClash Android app as a pinned, functioning networking
baseline. The first build is deliberately a **technical preview**: it retains
FlClash's Flutter user interface temporarily, changes the Android launcher
label and application ID, and disables Firebase telemetry.

- FlClash upstream: https://github.com/chen08209/FlClash
- Pinned commit: `c7be7023d33615cb624148d41414f80a7d96cede`
- Mihomo submodule: pinned by the upstream Git tree and fetched via HTTPS.
- Source license: FlClash GPL-3.0; corresponding patched source archive
  is published with each APK.
- Android test application ID: `com.neyjealous.remnantvpn.android.dev`
- Build: Flutter 3.47.1, Go 1.26.4, Rust stable, NDK r28c, Java 17.

## Acceptance gates

1. Build a self-contained, debug-signed arm64 APK with native Mihomo present.
2. On an Android phone, import the **same known-good Hysteria2 endpoint** that
   works in Happ; verify that it is interpreted correctly by Mihomo.
3. Prove actual traffic: DNS, HTTPS, UDP and external IP, not just a VPN icon.
4. Run connect → disconnect → connect five times.
5. Switch Wi-Fi → cellular and back; verify no stale DNS or blocked traffic.
6. Capture adb logs for any failing transition.
7. Implement the Remnant VPN visual UI once the networking baseline passes.
8. Add VLESS/Xray and AWG 3.1 support only with per-protocol device tests.

Do not call the first preview a finished multi-protocol Remnant release.

## Build locally

```bash
./scripts/bootstrap-android-flclash.sh
cd .deps/FlClash
flutter pub get
dart setup.dart android --env dev --arch arm64 -v
```

The Android GitHub Actions workflow performs these steps on Ubuntu and
publishes a downloadable APK as a GitHub **prerelease**.

## Signing and privacy

The upstream Gradle release build falls back to Android debug signing and
adds `.dev` to the app ID when no release keystore is present. This is
appropriate for technical tests, but a fresh CI runner may use a different
debug key. Uninstall the previous test APK if the package manager reports a
signature mismatch. For stable in-place updates, configure a permanent
keystore later (never commit its private key to the repository).

The pilot disables Firebase app initialization and build plugins. No
production tracking or Google Services secret is required.

## Logs on Windows

Install Android Platform Tools and enable USB debugging on the device:

```powershell
adb devices
adb logcat -c
adb logcat -v time > remnant-android-logcat.txt
```

Reproduce the failed connection, stop logcat with Ctrl+C and remove
credentials, server addresses and tokens before sharing the log.

**Important:** The user currently tests the iOS version on an iPhone. Android
testing requires a separate physical Android device or compatible emulator;
a successful APK compilation alone cannot validate VPN connectivity.
