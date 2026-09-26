# FreeIntv Controller

FreeIntv Controller connects the Android phone app to the FreeIntv libretro core running in RetroArch on a Windows PC. The core includes the phone-controller receiver; no separate PC receiver application or ADB installation is required.

## Downloads

- [Windows RetroArch core DLL](FreeIntv-master/build/windows-msvc/freeintv_controller_libretro.dll)
- [Android controller app APK](mobile/build/app/outputs/flutter-apk/app-debug.apk)
- [Matching RetroArch core information file](FreeIntv-master/build/windows-msvc/freeintv_controller_libretro.info)

## Install the core in RetroArch on Windows

1. Close RetroArch.
2. Copy `freeintv_controller_libretro.dll` into RetroArch's `cores` directory. For example: `E:\RetroArch-Win64\cores\`.
3. Copy `freeintv_controller_libretro.info` into RetroArch's `info` directory. Its name must match the DLL name, apart from the extension.
4. Make sure the Intellivision BIOS files `exec.bin` and `grom.bin` are in RetroArch's `system` directory.
5. Start RetroArch and load an Intellivision ROM with **FreeIntv Controller**. If you replaced an earlier DLL, fully restart RetroArch before loading the game.

## Install the app on Android

1. Connect the phone to the PC with a USB cable and copy the APK to the phone. Alternatively, download the APK directly on the phone.
2. Open the APK on the phone and follow Android's installation prompts. If prompted, allow the file manager or browser to install apps from this source.
3. Open **Intellivision Controller**.

The USB cable is only needed to copy the APK. The controller currently communicates with the core over Wi-Fi: connect the phone and PC to the same private Wi-Fi network. Direct USB controller communication and Bluetooth are not implemented.

## Connect and play

1. In RetroArch, open the running game's **Quick Menu → Core Options**. Enable **Phone Controller over Wi-Fi** and restart the core if RetroArch requests it. The listener is disabled by default.
2. Load the game. The core displays the PC's local IP address in an on-screen message and in the RetroArch log.
3. Enter that IP address in the Android app. Enter the same pairing code configured in the core options; the default is `482731`.
4. Tap **Connect**. The app remembers the IP address and code. Use the keypad, directional disc, and action buttons to play.

If Windows Firewall asks, allow RetroArch on the private network. Both devices need to reach one another on local TCP port `55355`. Do not expose this port to the public internet.

## Game overlays

The controller works without a game overlay. When one is available, the core looks for a `.png` or `.jpg` image with the ROM's filename (without `.int`) beside the ROM, then in `system/freeintv_overlays`. For example, `Frog Bog (1982) (Mattel).int` can use `Frog Bog (1982) (Mattel).jpg`. After connecting, tap **OVERLAY** to show or hide the game card above the keypad.

## Troubleshooting

- Confirm RetroArch loaded **FreeIntv Controller**, not another FreeIntv core.
- Confirm both devices are on the same Wi-Fi network and the PC IP in the app is current.
- Check RetroArch's log for the core's phone-controller address and `[FreeIntv]` overlay messages.
- Confirm `exec.bin` and `grom.bin` are in RetroArch's `system` directory.

See [the mobile app guide](mobile/README.md) and [the FreeIntv core guide](FreeIntv-master/USER_GUIDE.md) for more details.

## Acknowledgements

This project builds on the [FreeIntv libretro core](https://github.com/GIEI/IntellivisionController/tree/main/FreeIntv-master). Thanks to its authors and contributors for the Intellivision emulation work: David Richardson, Oscar Toledo G., Joe Zbiciak, and the FreeIntv community.
