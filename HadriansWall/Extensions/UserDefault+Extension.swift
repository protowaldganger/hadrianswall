//
//  UserDefault+Extension.swift
//  Hadrian's Wall
//

import Foundation

extension UserDefaults {
    enum Key {
        static let globalKey = "globalKey"
        static let numberOfSecondForAutoHide = "numberOfSecondForAutoHide"
        static let isAutoStart = "isAutoStart"
        static let isAutoHide = "isAutoHide"
        static let isShowPreference = "isShowPreferences"
        static let areSeparatorsHidden = "areSeparatorsHidden"
        static let alwaysHiddenSectionEnabled = "alwaysHiddenSectionEnabled"
        static let hoverToExpand = "hoverToExpand"
        static let newIconsVisible = "newIconsVisible"
        static let knownMenuBarApps = "knownMenuBarApps"
        static let hasHiddenIcons = "hasHiddenIcons"
    }
}
