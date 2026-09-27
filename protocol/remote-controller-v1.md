# Remote controller protocol v1

The Flutter app sends fixed 16-byte state snapshots over a byte stream. The FreeIntv Windows core supports either TCP over Wi-Fi (port `55355`) or Bluetooth Classic RFCOMM using the Serial Port Profile UUID `00001101-0000-1000-8000-00805F9B34FB`. Only one transport is active at a time. Before Bluetooth use, pair the PC and phone in their operating-system Bluetooth settings; select that PC in the app. The app first sends the pairing code followed by LF, which must match the code configured in RetroArch Core Options. The current handshake sends the code in plaintext; Bluetooth link pairing encrypts the radio link, but the protocol has no application-level encryption.

Each packet is little-endian:

| Offset | Size | Meaning |
|---:|---:|---|
| 0 | 4 | ASCII `FIV1` |
| 4 | 4 | Incrementing sequence number |
| 8 | 4 | Button bitfield |
| 12 | 2 | Stick X, signed -32768…32767 |
| 14 | 2 | Stick Y, signed -32768…32767; positive is down |

The bitfield uses bits 0–3 for up/down/left/right; 4–6 for left/right/top action; 7–18 for keypad `1,2,3,4,5,6,7,8,9,Clear,0,Enter`; 19 for pause and 20 for controller swap. The keypad is single-selection in the UI; action buttons and disc movement can be held together.

The phone sends a snapshot every 20 ms, including unchanged state. The core polls the nonblocking socket from `retro_run()` input polling, accepts one client, and clears state after 500 ms without a valid packet or when the connection closes. Invalid/stale sequence numbers are ignored. Stream data may split or combine packets, so the receiver re-synchronizes on the packet magic.

After pairing, the core sends one ROM overlay response to the phone. Its 10-byte header is `FIO1`, a 32-bit little-endian image length, and a 16-bit little-endian MIME length, followed by the MIME string and encoded PNG/JPG bytes. A zero image length means that the current ROM has no overlay. Images larger than 8 MiB are not transferred. The phone caches the image for the session; its OVERLAY control toggles the image over the keypad without intercepting touches.

The Wi-Fi transport requires the phone and PC to share a trusted LAN. The port must not be forwarded/exposed to the internet. Bluetooth connections require operating-system pairing and the Android runtime Bluetooth Connect permission; no separate Android receiver app or ADB installation is needed.

The FreeIntv core accepts per-ROM overlay images as PNG or JPG, named after the ROM basename without its extension. It checks beside the ROM first, then `system/freeintv_overlays/` (for example, `frogbog.jpg` for `frogbog.bin`).
