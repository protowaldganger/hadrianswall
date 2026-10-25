# Hadrian's Wall

Hide menu bar icons behind a wall. Click the arrow to show them, click again to put them away.

Made by protowaldganger.

## Install

1. Download `HadriansWall.dmg` from [Releases](../../releases/latest), open it and drag Hadrian's Wall onto Applications.
2. Open it. macOS warns that it cannot verify the developer, because the app is not notarized. Open System Settings › Privacy & Security, scroll down and click Open Anyway.
3. Follow the short checklist that opens: on macOS 27 it asks for Accessibility, which is how the app sees where your icons sit, and ticks each step off as you go.

## Use

- ⌘-drag icons left of the arrow to hide them, right of it to keep them.
- Click the arrow to show or hide. Right-click it for Settings.
- ⌥-click the arrow to reveal the always-hidden section, when it is on.
- On macOS 27, icons of newly installed apps start out visible. Settings › Menu Bar › New icons switches that to hidden.

The app has to run from /Applications.

## Private by design

No analytics, no tracking. It goes online only if you turn on Check for updates (off by default). Then it asks GitHub once a day which release is newest, with no cookies and nothing about your Mac, and shows a link if there is a newer one. Nothing downloads by itself.

## Build

Requires Xcode and macOS 13 or later.

```
xcodebuild -project HadriansWall.xcodeproj -scheme HadriansWall -configuration Release-Direct -derivedDataPath build
cp -R "build/Build/Products/Release-Direct/Hadrian's Wall.app" /Applications/
```

To make the disk image for a release:

```
zsh make-dmg.sh "build/Build/Products/Release-Direct/Hadrian's Wall.app" build/HadriansWall.dmg
```

## Uninstall

```
rm -rf "/Applications/Hadrian's Wall.app"
defaults delete com.protowaldganger.hadrianswall
tccutil reset Accessibility com.protowaldganger.hadrianswall
```
