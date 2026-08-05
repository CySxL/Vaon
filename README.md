# Vaon
An iOS jailbreak tweak that shows Bluetooth device battery information in the app switcher.

 ![Vaon Animation](./assets/Vaon_animation.gif)

## Features
Vaon shows connected Bluetooth accessories in the app switcher, with their battery level where iOS has one. For the original feature set and screenshots, see the [original repository](https://github.com/atar13/Vaon). This fork targets iOS 16 and differs from the original; its changes are listed below.

## Compatibility
Vaon currently targets **iOS 16 only** (rootless and roothide).

Development and testing are done on iOS 16 hardware only, which is the hardware available to the current maintainer. Because the changes cannot be verified on earlier versions, support for iOS 13 to 15 has been removed and the tweak activates only on iOS 16.

The option that switched the app switcher to an iPad style grid has also been removed, so development can focus on the battery module. If you want a grid app switcher, use a dedicated tweak for that alongside Vaon.

## What changed in this fork
- iOS 16 support for rootless and roothide. Support for iOS 13 to 15 has been removed
- The iPad style grid app switcher option has been removed
- Bluetooth accessories that send iOS no battery level, such as speakers, soundbars and car stereos, are now shown. The device list previously came only from the accessories iOS holds a battery reading for, so these never appeared at all
- An accessory with no battery reading shows an infinity sign in place of a percentage, and a full ring that pulses while it is connected
- Cell Color Configuration gained connected and disconnected colours for those accessories
- Pinned Devices, with persistence across respring, drag to reorder, and custom SF Symbol glyphs
- The glyph picker covers 71 symbols grouped by accessory type
- A page based layout with a configurable per page device count and page dots
- Page dot options: vertical dots, showing them only while swiping, and remembering the last page
- Landscape (beta): hide, or offset Vaon to avoid overlapping a floating dock
- Stored device records are keyed on the accessory rather than on the identifier iOS supplies. That identifier changes between connections, and a record with its own copy of the device glyph was being kept for every variation
- Fix: the brief left aligned "all devices" view no longer appears when the switcher opens
- Fix: the app switcher home gesture is no longer disrupted when swiping up near the Vaon module

## Build
Install Theos, then build a package with:

 ```
 make clean && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
 ```

 For a rootless package, use ```THEOS_PACKAGE_SCHEME=rootless``` instead.

## Credits
Originally created by atar13. The iOS 16 port and the changes above are by CySxL. See the in app Contact section for links.

## License
This project is licensed under the terms of the MIT License.
