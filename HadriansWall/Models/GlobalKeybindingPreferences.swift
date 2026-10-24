//
//  GlobalKeybindingPreferences.swift
//  Hadrian's Wall
//

import Foundation

// The stored global shortcut. Field names are the persisted JSON keys, so they
// stay as they are for existing users.
struct GlobalKeybindPreferences: Codable, CustomStringConvertible {
    let function: Bool
    let control: Bool
    let command: Bool
    let shift: Bool
    let option: Bool
    let capsLock: Bool
    let carbonFlags: UInt32
    let characters: String?
    let keyCode: UInt32

    // Keys whose character is unprintable or misleading. F-keys arrive with the
    // .function flag set, so they get their real name instead of "Fn".
    private static let namedKeys: [UInt32: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
        80: "F19", 90: "F20",
        36: "⏎", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟"
    ]

    var isFunctionKey: Bool { (Self.namedKeys[keyCode] ?? "").hasPrefix("F") }

    // One entry per key, in the order macOS draws them: ⌃ ⌥ ⇧ ⌘, then the key.
    var keys: [String] {
        var keys: [String] = []
        if function && !isFunctionKey { keys.append("fn") }
        if control { keys.append("⌃") }
        if option { keys.append("⌥") }
        if shift { keys.append("⇧") }
        if command { keys.append("⌘") }
        if capsLock { keys.append("⇪") }
        if let name = Self.namedKeys[keyCode] {
            keys.append(name)
        } else if let characters, !characters.isEmpty {
            keys.append(characters.uppercased())
        }
        return keys
    }

    var description: String { keys.joined() }
}
