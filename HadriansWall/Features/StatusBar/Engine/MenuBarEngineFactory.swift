//
//  MenuBarEngineFactory.swift
//  Hadrian's Wall
//

import Foundation

// The single place that picks a hiding mechanism for the running OS.
enum MenuBarEngineFactory {
    static func make(items: MenuBarItemProvider) -> MenuBarEngine {
        // macOS 27 ejects an inflated separator from the menu bar. The
        // direct build hides natively there instead. The App Store build cannot:
        // the sandbox blocks the Accessibility reads that locate the sections.
        #if NATIVE_VISIBILITY
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            let defaults = UserDefaults.standard
            let policy = NewIconPolicy(
                showsNewIcons: { Preferences.newIconsVisible },
                load: { defaults.stringArray(forKey: UserDefaults.Key.knownMenuBarApps).map { Set($0) } },
                save: { defaults.set($0.sorted(), forKey: UserDefaults.Key.knownMenuBarApps) })
            return NativeVisibilityEngine(items: items, newIconPolicy: policy)
        }
        #endif
        return LegacyLengthEngine(items: items)
    }
}
