//
//  SettingsWindow.swift
//  Hadrian's Wall
//

import AppKit
import ApplicationServices
import SwiftUI

// The one window. Built on first use, kept (not released) when closed.
enum SettingsWindow {
    private static var window: NSWindow?
    private static let model = SettingsModel()

    static var isVisible: Bool { window?.isVisible ?? false }

    static func show(_ pane: SettingsPane? = nil) {
        if let pane { model.pane = pane }
        let window = self.window ?? makeWindow()
        self.window = window
        model.refresh()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: SettingsView.size),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered,
                              defer: true)
        window.title = Constant.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        window.setContentSize(SettingsView.size)
        window.center()
        window.setFrameAutosaveName("WallSettings")
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            SettingsWindow.model.stopRecording()
        }
        return window
    }
}

enum SettingsPane: Int, CaseIterable, Identifiable {
    case general, menuBar, shortcut, about

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general: return "General".localized
        case .menuBar: return "Menu Bar".localized
        case .shortcut: return "Shortcut".localized
        case .about: return "About".localized
        }
    }

    // Each pane is a letter, the way a pinned site is in Search.
    var letter: String { String(title.prefix(1)).uppercased() }
}

// How hiding works on this Mac right now, in words the user can act on.
enum HidingStatus: Equatable {
    case widening              // macOS 26 and earlier
    case native                // macOS 27, direct build, permission granted
    case needsAccessibility    // macOS 27, permission missing
    case notInApplications     // macOS 27, running from somewhere else
    case unavailable           // macOS 27 without the native mechanism

    static var current: HidingStatus {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 else { return .widening }
        guard WallNativeVisibilityIsAvailable() else { return .unavailable }
        guard AXIsProcessTrusted() else { return .needsAccessibility }
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else { return .notInApplications }
        return .native
    }

    // On macOS 27 the arrow itself is the divider.
    var arrowIsBoundary: Bool { self != .widening }

    var isWorking: Bool { self == .widening || self == .native }

    var title: String {
        switch self {
        case .widening, .native: return "Hiding is on".localized
        case .needsAccessibility: return "Needs Accessibility access".localized
        case .notInApplications: return "Move Hadrian's Wall to Applications".localized
        case .unavailable: return "Hiding is unavailable".localized
        }
    }

    var detail: String {
        switch self {
        case .widening:
            return "The divider widens to push hidden icons off the bar.".localized
        case .native:
            return "macOS hides the icons itself. Apps hide with all their icons.".localized
        case .needsAccessibility:
            return "Hadrian's Wall reads where your icons sit. Until it can, the bar stays open.".localized
        case .notInApplications:
            return "Run from another folder, macOS hides Hadrian's Wall's own arrow.".localized
        case .unavailable:
            return "This build or macOS version has no way to hide icons. The bar stays open.".localized
        }
    }

    static func openAccessibilitySettings() {
        // Registers the app in the list, then opens the pane it lives in.
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// View state. Settings themselves live in Preferences; this only tells SwiftUI
// to redraw when they change, wherever the change came from.
final class SettingsModel: ObservableObject {
    @Published var pane: SettingsPane = .general
    @Published private(set) var status = HidingStatus.current
    @Published private(set) var isRecording = false

    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers = [Notification.Name.prefsChanged, NSApplication.didBecomeActiveNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        stopRecording()
    }

    func refresh() {
        status = HidingStatus.current
        objectWillChange.send()
    }

    // MARK: Shortcut recording

    func startRecording() {
        guard keyMonitor == nil else { return }
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil
        }
    }

    func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        isRecording = false
    }

    func clearShortcut() {
        stopRecording()
        Preferences.globalKey = nil
        (NSApp.delegate as? AppDelegate)?.applyGlobalKey()
    }

    private func record(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifier = !flags.isDisjoint(with: [.command, .option, .control, .shift])
        let key = GlobalKeybindPreferences(function: flags.contains(.function),
                                           control: flags.contains(.control),
                                           command: flags.contains(.command),
                                           shift: flags.contains(.shift),
                                           option: flags.contains(.option),
                                           capsLock: flags.contains(.capsLock),
                                           carbonFlags: flags.carbonFlags,
                                           characters: event.charactersIgnoringModifiers,
                                           keyCode: UInt32(event.keyCode))
        switch (event.keyCode, hasModifier) {
        case (53, false):                 // Esc cancels
            stopRecording()
        case (51, false), (117, false):   // Delete clears
            clearShortcut()
        case (_, false) where !key.isFunctionKey:
            NSSound.beep()                // a bare letter would fire while typing
        default:
            Preferences.globalKey = key
            (NSApp.delegate as? AppDelegate)?.applyGlobalKey()
            stopRecording()
        }
    }
}
