//
//  Constant.swift
//  Hadrian's Wall
//

import AppKit

enum Constant {
    static let appName = "Hadrian's Wall"

    // Read live rather than cached at launch: the status items are built before
    // any launch hook runs, and a cached `false` made the arrow start out
    // pointing the wrong way in left-to-right languages.
    static var isUsingLTRLanguage: Bool {
        NSApplication.shared.userInterfaceLayoutDirection == .leftToRight
    }
}
