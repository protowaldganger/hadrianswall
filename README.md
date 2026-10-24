# Hadrian's Wall

Hide menu bar icons behind a wall. Click the arrow to show them, click again to put them away.

Made by protowaldganger.

## Use

- ⌘-drag icons left of the arrow to hide them, right of it to keep them.
- Click the arrow to show or hide. Right-click it for Settings.
- ⌥-click the arrow to reveal the always-hidden section, when it is on.

On macOS 27 the app needs Accessibility access and has to run from /Applications.

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
