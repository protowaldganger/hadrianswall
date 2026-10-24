# Hadrian's Wall

Hide menu bar icons behind a wall. Click the arrow to show them, click again to put them away.

Made by protowaldganger.

## Install

1. Download `HadriansWall.zip` from [Releases](../../releases/latest), unzip it and drag Hadrian's Wall into Applications.
2. Open it. macOS warns that it cannot verify the developer, because the app is not notarized. Open System Settings › Privacy & Security, scroll down and click Open Anyway.
3. On macOS 27, allow Accessibility when asked. It is how the app sees where your icons sit.

## Use

- ⌘-drag icons left of the arrow to hide them, right of it to keep them.
- Click the arrow to show or hide. Right-click it for Settings.
- ⌥-click the arrow to reveal the always-hidden section, when it is on.

The app has to run from /Applications.

## Build

Requires Xcode and macOS 13 or later.

```
xcodebuild -project HadriansWall.xcodeproj -scheme HadriansWall -configuration Release-Direct -derivedDataPath build
cp -R "build/Build/Products/Release-Direct/Hadrian's Wall.app" /Applications/
```

## Uninstall

```
rm -rf "/Applications/Hadrian's Wall.app"
defaults delete com.protowaldganger.hadrianswall
tccutil reset Accessibility com.protowaldganger.hadrianswall
```
