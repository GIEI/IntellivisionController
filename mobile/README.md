# Intellivision Controller (Android MVP)

This Flutter app sends touchscreen controller state directly to the FreeIntv core. There is no separate PC receiver process.

## Connection setup (no ADB required)

1. Load a game with **FreeIntv Controller**. In RetroArch **Quick Menu → Core Options**, choose **Phone Controller Connection** as Wi-Fi or Bluetooth, set **Phone Controller Pairing Code** (default `482731`), and restart the core if requested. The receiver is disabled by default.
2. For Wi-Fi, connect both devices to the same trusted network, then enter the PC's local IPv4 address shown in RetroArch in the app.
3. For Bluetooth, enable Bluetooth and pair the PC and phone in Windows and Android Bluetooth settings. Keep the PC discoverable while pairing. In the app select **Bluetooth**, refresh the device list if needed, select the paired PC, enter the same pairing code, and connect. Android 12 or later will ask for Bluetooth/Nearby Devices permission.

The host listener is Windows-only, accepts one phone, and releases all inputs after 500 ms without packets. Wi-Fi uses TCP port 55355 and must not be exposed to the internet. Bluetooth uses Bluetooth Classic SPP/RFCOMM and needs no shared Wi-Fi network or PC IP address. System pairing protects the Bluetooth radio link. No PC receiver program, ADB, USB debugging, or driver is required. Only one transport can be active at a time.

When the loaded ROM has a matching PNG or JPG, the core transfers it to the phone after pairing. The core checks the ROM's folder first, then `system/freeintv_overlays`. Tap **OVERLAY** to show or hide it above the 12 keypad buttons; the overlay layer does not block button touches. Image names must match the ROM basename, for example `Frog Bog.jpg` for `Frog Bog.bin`.

The controller body is widened to use more of the phone display, and the Mattel/Intellivision brand plate has been removed. ROM overlays retain their original aspect ratio; their printed title and keypad artwork remain aligned with the touch controls. PAUSE, SWAP, and OVERLAY sit in a toolbar outside the controller body. While connected, the complete controller scales to the available screen without scrolling. Cards with a different printed key layout may need separate alignment metadata in a future version.

## Packet reference

See [`../protocol/remote-controller-v1.md`](../protocol/remote-controller-v1.md).
