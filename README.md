# FreeIntv Controller

FreeIntv Controller connects the Android phone app to the FreeIntv libretro core running in RetroArch on a Windows PC. The core includes the phone-controller receiver; no separate PC receiver application or ADB installation is required.

## Downloads

- [Windows RetroArch core DLL](https://github.com/GIEI/IntellivisionController/releases/latest/download/freeintv_controller_libretro.dll)
- [Android controller app APK](https://github.com/GIEI/IntellivisionController/releases/latest/download/Intellivision.Controller.apk)
- [RetroArch core information file](https://github.com/GIEI/IntellivisionController/releases/latest/download/freeintv_controller_libretro.info)

All three download links point to assets attached to the latest GitHub Release.

## Install the core in RetroArch on Windows

1. Close RetroArch.
2. Copy `freeintv_controller_libretro.dll` into RetroArch's `cores` directory. For example: `E:\RetroArch-Win64\cores\`.
3. Copy `freeintv_controller_libretro.info` into RetroArch's `info` directory. Its name matches the DLL.
4. Make sure the Intellivision BIOS files `exec.bin` and `grom.bin` are in RetroArch's `system` directory.
5. Start RetroArch and load an Intellivision ROM with **FreeIntv Controller**. If you replaced an earlier DLL, fully restart RetroArch before loading the game.

## Install the app on Android

1. Connect the phone to the PC with a USB cable and copy the APK to the phone. Alternatively, download the APK directly on the phone.
2. Open the APK on the phone and follow Android's installation prompts. If prompted, allow the file manager or browser to install apps from this source.
3. Open **Intellivision Controller**.

The USB cable is only needed to copy the APK. The app can communicate over Wi-Fi or Bluetooth Classic; no separate PC receiver application, ADB installation, or USB debugging setup is needed.

## Connect and play

The phone controller is disabled by default. In RetroArch, open the game's **Quick Menu → Core Options → Phone Controller Connection**, select a transport, and restart the core when prompted. Wi-Fi and Bluetooth are alternatives; only one can be active at a time. Set **Phone Controller Pairing Code** to the same code used in the app (default: `482731`).

### Wi-Fi

1. Connect the PC and phone to the same private network.
2. Load the game and enter the PC's local IP address, shown by the core, in the app.
3. Enter the pairing code and connect. If Windows Firewall asks, allow RetroArch on the private network.

### Bluetooth

1. Select **Bluetooth** for **Phone Controller Connection** in RetroArch and restart the core with a game loaded.
2. Turn on Bluetooth and pair the PC and phone in Windows and Android Bluetooth settings. Keep the PC discoverable while pairing.
3. In the app, select **Bluetooth**, refresh the paired-device list if needed, choose the PC, enter the pairing code, and connect. On Android 12 or later, allow the app's Bluetooth/Nearby Devices permission when asked.

Bluetooth connects directly to the core using Bluetooth Classic SPP/RFCOMM. It does not require the devices to share a Wi-Fi network or an IP address. The app remembers the selected transport and connection details.

Wi-Fi uses local TCP port `55355`; do not expose this port to the public internet. Bluetooth uses Bluetooth Classic SPP/RFCOMM after operating-system pairing. Only one transport can be active at a time.

## Game overlays

The controller works without a game overlay. When one is available, the core looks for a `.png` or `.jpg` image with the ROM's filename (without `.int`) beside the ROM, then in `system/freeintv_overlays`. For example, `Frog Bog (1982) (Mattel).int` can use `Frog Bog (1982) (Mattel).jpg`. After connecting, tap **OVERLAY** to show or hide the game card above the keypad.

## Troubleshooting

- Confirm RetroArch loaded **FreeIntv Controller**, not another FreeIntv core.
- For Wi-Fi, confirm both devices are on the same network and the PC IP in the app is current. For Bluetooth, confirm the core is set to Bluetooth, both systems show the devices as paired, Bluetooth is enabled, and the Android permission is granted. Refresh the app's paired-device list after pairing.
- Check RetroArch's log for the core's phone-controller address and `[FreeIntv]` overlay messages.
- Confirm `exec.bin` and `grom.bin` are in RetroArch's `system` directory.

See [the mobile app guide](mobile/README.md) and [the FreeIntv core guide](FreeIntv-master/USER_GUIDE.md) for more details.

## Acknowledgements

This project builds on the [FreeIntv libretro core](https://github.com/GIEI/IntellivisionController/tree/main/FreeIntv-master). Thanks to its authors and contributors for the Intellivision emulation work: David Richardson, Oscar Toledo G., Joe Zbiciak, and the FreeIntv community.
