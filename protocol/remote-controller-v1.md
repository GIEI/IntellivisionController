# Remote controller protocol v1

The Flutter app sends fixed 16-byte state snapshots over a TCP stream. The FreeIntv core's Windows listener accepts connections on local interfaces at TCP port `55355`. The app first sends the pairing code followed by LF, which must match the code configured in RetroArch Core Options. The current handshake sends the code in plaintext; use only on a trusted LAN during development. Add authenticated encryption before public distribution.

Each packet is little-endian:

| Offset | Size | Meaning |
|---:|---:|---|
| 0 | 4 | ASCII `FIV1` |
| 4 | 4 | Incrementing sequence number |
| 8 | 4 | Button bitfield |
| 12 | 2 | Stick X, signed -32768…32767 |
| 14 | 2 | Stick Y, signed -32768…32767; positive is down |

The bitfield uses bits 0–3 for up/down/left/right; 4–6 for left/right/top action; 7–18 for keypad `1,2,3,4,5,6,7,8,9,Clear,0,Enter`; 19 for pause and 20 for controller swap. The keypad is single-selection in the UI; action buttons and disc movement can be held together.

The phone sends a snapshot every 20 ms, including unchanged state. The core polls the nonblocking socket from `retro_run()` input polling, accepts one client, and clears state after 500 ms without a valid packet or when the connection closes. Invalid/stale sequence numbers are ignored. TCP data may split or combine packets, so the receiver re-synchronizes on the packet magic.

Bluetooth and a direct USB accessory transport are not part of this initial implementation. The Wi-Fi transport requires the phone and PC to share a trusted LAN. The port must not be forwarded/exposed to the internet. The pairing code is not encryption; transport encryption/authenticated pairing remains a release-hardening task.

The FreeIntv core accepts per-ROM overlay images as PNG or `.jpg`, named after the ROM basename without its extension, under `system/freeintv_overlays/` (for example, `frogbog.jpg` for `frogbog.bin`).
