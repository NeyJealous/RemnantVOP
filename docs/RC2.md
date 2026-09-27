# Remnant VPN 1.0.0 RC2

RC2 is a device-runtime repair build based on feedback from RC1.

## Fixes

- `vpn://` import now mirrors Amnezia's compatibility behavior: Base64-decoded JSON is accepted directly when Qt-style decompression is not applicable.
- Supports ordinary `qCompress` keys, the `000000ff` Amnezia API signature variant, and raw zlib variants.
- sing-box waits for the first real `NWPath` before Hysteria2 starts, preventing a TUN from becoming active before a physical egress interface is known.
- Network interface state is now initialized and reset closer to the official sing-box Apple implementation.
- Hysteria2 shutdown no longer recursively closes the command service.
- A 100 ms core shutdown grace period is applied before closing the Libbox command server.
- The app waits for the previous NetworkExtension session to fully reach `disconnected` before restarting another protocol.

## Device test order

1. Import the same Amnezia `vpn://` key that RC1 rejected.
2. Connect Hysteria2 and verify HTTPS access.
3. Disconnect Hysteria2, wait for the UI to show disconnected, reconnect it.
4. Repeat Hysteria2 connect/disconnect three times.
5. Connect AWG 3.1 with the imported key.
