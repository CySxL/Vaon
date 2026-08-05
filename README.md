# Vaon
An iOS jailbreak tweak that shows Bluetooth device battery information in the app switcher.

 ![Vaon Animation](./assets/Vaon_animation.gif)

## Features
Vaon shows connected Bluetooth accessories in the app switcher, with their battery level where iOS has one. For the original feature set and screenshots, see the [original repository](https://github.com/atar13/Vaon). This fork targets iOS 16 and differs from the original. Changes are listed below.

## Compatibility
Vaon currently targets **iOS 16 only** (rootless and roothide).

Development and testing happen on iOS 16 only, because that is the hardware the maintainer has. Nothing can be verified on earlier versions, so support for iOS 13 to 15 has been removed and the tweak only runs on iOS 16.

The iPad style grid app switcher option has also been removed, to keep the focus on the battery module. If you want a grid app switcher, run a dedicated tweak for it alongside Vaon.

## What changed in this fork
- iOS 16 support for rootless and roothide. Support for iOS 13 to 15 has been removed
- The iPad style grid app switcher option has been removed
- Speakers, soundbars, car stereos and anything else that does not report a battery level now appear. The list used to come only from accessories iOS has a battery reading for, so these were missing completely
- Accessories with no battery reading show an infinity sign instead of a percentage, and a full ring that pulses while connected
- Cell Color Configuration gained connected and disconnected colours for those accessories
- Pinned Devices, which survive a respring, can be dragged to reorder, and take a custom SF Symbol glyph
- The glyph picker covers 71 symbols grouped by accessory type
- A paged layout with page dots and a configurable number of devices per page
- Page dot options: vertical dots, showing them only while swiping, and remembering the last page
- Landscape (beta): hide, or offset Vaon to avoid overlapping a floating dock
- Device records are keyed on the accessory instead of the identifier iOS supplies. That identifier changes between connections, so every variation used to leave another record behind, each with its own copy of the glyph
- Fix: the brief left aligned "all devices" view no longer appears when the switcher opens
- Fix: the app switcher home gesture is no longer disrupted when swiping up near the Vaon module

## Build
Install Theos, then build a package with:

 ```
 make clean && make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide
 ```

 For a rootless package, use ```THEOS_PACKAGE_SCHEME=rootless``` instead.

## Credits
Originally created by atar13. The iOS 16 port and the changes above are by CySxL. See the Contact section in the app for links.

## License
This project is licensed under the terms of the MIT License.
