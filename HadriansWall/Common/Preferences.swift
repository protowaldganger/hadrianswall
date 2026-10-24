//
//  Preferences.swift
//  Hadrian's Wall
//

import Foundation

// Typed access to UserDefaults. Every setter posts `.prefsChanged`, so the
// status bar and the Settings window stay in sync whichever one made the change.
enum Preferences {
    private typealias Key = UserDefaults.Key
    private static var defaults: UserDefaults { .standard }

    private static func store(_ value: Any?, for key: String, also extra: Notification.Name? = nil) {
        defaults.set(value, forKey: key)
        if let extra { NotificationCenter.default.post(name: extra, object: nil) }
        NotificationCenter.default.post(name: .prefsChanged, object: nil)
    }

    static var globalKey: GlobalKeybindPreferences? {
        get { defaults.data(forKey: Key.globalKey).flatMap { try? JSONDecoder().decode(GlobalKeybindPreferences.self, from: $0) } }
        set { store(newValue.flatMap { try? JSONEncoder().encode($0) }, for: Key.globalKey) }
    }

    static var isAutoStart: Bool {
        get { defaults.bool(forKey: Key.isAutoStart) }
        // Apply first, then persist the outcome, so a refused login item shows
        // as off instead of as the intent.
        set { store(AutoStart.apply(enabled: newValue) ? newValue : isAutoStart, for: Key.isAutoStart) }
    }

    static var numberOfSecondForAutoHide: Double {
        get { defaults.double(forKey: Key.numberOfSecondForAutoHide) }
        set { store(newValue, for: Key.numberOfSecondForAutoHide) }
    }

    static var isAutoHide: Bool {
        get { defaults.bool(forKey: Key.isAutoHide) }
        set { store(newValue, for: Key.isAutoHide) }
    }

    static var isShowPreference: Bool {
        get { defaults.bool(forKey: Key.isShowPreference) }
        set { store(newValue, for: Key.isShowPreference) }
    }

    // Written by the status bar itself, which already knows; no broadcast.
    static var areSeparatorsHidden: Bool {
        get { defaults.bool(forKey: Key.areSeparatorsHidden) }
        set { defaults.set(newValue, forKey: Key.areSeparatorsHidden) }
    }

    static var alwaysHiddenSectionEnabled: Bool {
        get { defaults.bool(forKey: Key.alwaysHiddenSectionEnabled) }
        set { store(newValue, for: Key.alwaysHiddenSectionEnabled, also: .alwayHideToggle) }
    }

    static var hoverToExpand: Bool {
        get { defaults.bool(forKey: Key.hoverToExpand) }
        set { store(newValue, for: Key.hoverToExpand) }
    }

    static var useFullStatusBarOnExpandEnabled: Bool {
        get { defaults.bool(forKey: Key.useFullStatusBarOnExpandEnabled) }
        set { store(newValue, for: Key.useFullStatusBarOnExpandEnabled) }
    }

    static var notchOverflowEnabled: Bool {
        get { defaults.bool(forKey: Key.notchOverflowEnabled) }
        set { store(newValue, for: Key.notchOverflowEnabled) }
    }
}
