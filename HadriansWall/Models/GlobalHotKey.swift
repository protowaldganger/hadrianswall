//
//  GlobalHotKey.swift
//  Hadrian's Wall
//

import AppKit
import Carbon.HIToolbox

// A system-wide shortcut through Carbon's RegisterEventHotKey, the only public
// API that fires while another app is frontmost and needs no permission.
// Unregistered when released.
final class GlobalHotKey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?

    private let id: UInt32
    private var reference: EventHotKeyRef?

    init?(keyCode: UInt32, carbonModifiers: UInt32, action: @escaping () -> Void) {
        id = Self.nextID
        Self.nextID += 1
        Self.installEventHandler()
        let hotKeyID = EventHotKeyID(signature: OSType(0x5741_4C4C), id: id) // 'WALL'
        guard RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &reference) == noErr else {
            return nil
        }
        Self.actions[id] = action
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        Self.actions[id] = nil
    }

    // One handler for every shortcut; it looks up which one fired.
    private static func installEventHandler() {
        guard eventHandler == nil else { return }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            GlobalHotKey.actions[hotKeyID.id]?()
            return noErr
        }, 1, &pressed, nil, &eventHandler)
    }
}

extension NSEvent.ModifierFlags {
    // The modifier mask RegisterEventHotKey expects.
    var carbonFlags: UInt32 {
        var flags = 0
        if contains(.command) { flags |= cmdKey }
        if contains(.option) { flags |= optionKey }
        if contains(.control) { flags |= controlKey }
        if contains(.shift) { flags |= shiftKey }
        return UInt32(flags)
    }
}
