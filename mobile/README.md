# Intellivision Controller (Android MVP)

This Flutter app sends touchscreen controller state directly to the FreeIntv core. There is no separate PC receiver process.

## Current Wi-Fi setup (no ADB required)

1. Build and load a FreeIntv core containing the integrated listener.
2. Enable the core option **Phone Controller over Wi-Fi** and set a unique pairing code of at least six digits in Core Options. The network listener is disabled by default.
3. Connect the PC and Android phone to the same trusted Wi-Fi network. When the game loads, RetroArch displays the PC's local IPv4 address in an on-screen notification and writes it to the RetroArch log.
4. Enter the PC IP and matching pairing code in the app, then tap Connect. The app remembers these values locally.

The current host listener is Windows-only, accepts one phone on TCP port 55355, and releases all inputs after 500 ms without packets. No PC receiver program, ADB, USB debugging, or driver is required. If Windows Firewall asks, allow RetroArch on the private network. Both devices must be on the same local network; do not expose port 55355 to the internet. Pairing currently sends the code in plaintext and is suitable only for development on a trusted LAN; authenticated encryption is required before public distribution. Direct Bluetooth and USB accessory transports are future work.

When the loaded ROM has a matching PNG or JPG, the core transfers it to the phone after pairing. The core checks the ROM's folder first, then `system/freeintv_overlays`. Tap **OVERLAY** to show or hide it above the 12 keypad buttons; the overlay layer does not block button touches. Image names must match the ROM basename, for example `Frog Bog.jpg` for `Frog Bog.bin`.

The card retains its original aspect ratio and includes a header above the keypad for the game title. The square buttons and overlay touch regions share the same positions, calibrated to the printed first row on the classic BurgerTime card. PAUSE, SWAP, and OVERLAY sit in a toolbar outside the controller body. While connected, the complete controller scales to the available screen without scrolling. Cards with a different printed key layout may need separate alignment metadata in a future version.

## Packet reference

See [`../protocol/remote-controller-v1.md`](../protocol/remote-controller-v1.md).
