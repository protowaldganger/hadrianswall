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
        model.startPolling()
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
        // The window, not SwiftUI, decides the size. Left to itself the hosting
        // controller adds the title bar's height on top of the content, and
        // since the content already runs under the title bar, that height
        // showed up as an empty strip along the bottom.
        let content = NSHostingController(rootView: SettingsView(model: model))
        content.sizingOptions = []
        window.contentViewController = content
        window.setContentSize(SettingsView.size)
        window.center()
        window.setFrameAutosaveName("WallSettings")
        // The saved frame keeps its place but not an older, smaller size.
        window.setContentSize(SettingsView.size)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            SettingsWindow.model.stopRecording()
            SettingsWindow.model.stopPolling()
        }
        return window
    }
}

enum SettingsPane: Int, CaseIterable, Identifiable {
    case general, menuBar, shortcut, about

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .menuBar: return "Menu Bar"
        case .shortcut: return "Shortcut"
        case .about: return "About"
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
        case .widening, .native: return "Hiding is on"
        case .needsAccessibility: return "Needs Accessibility access"
        case .notInApplications: return "Move Hadrian's Wall to Applications"
        case .unavailable: return "Hiding is unavailable"
        }
    }

    var detail: String {
        switch self {
        case .widening:
            return "The divider widens to push hidden icons off the bar."
        case .native:
            return "macOS hides the icons itself. Apps hide with all their icons."
        case .needsAccessibility:
            return "Hadrian's Wall reads where your icons sit. Until it can, the bar stays open."
        case .notInApplications:
            return "Run from another folder, macOS hides Hadrian's Wall's own arrow."
        case .unavailable:
            return "This build or macOS version has no way to hide icons. The bar stays open."
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

// The first-run checklist. On macOS 27 hiding needs the app in /Applications
// and Accessibility access; everywhere, setup is done once something has hidden.
// Each step is read live, so it ticks itself off as soon as it is true.
enum Setup {
    struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let done: Bool
        var actionTitle: String? = nil
        var action: (() -> Void)? = nil
    }

    static var steps: [Step] {
        let status = HidingStatus.current
        // Without the native mechanism there is nothing to set up; the status
        // card explains instead.
        if status == .unavailable { return [] }
        var steps: [Step] = []
        if status.arrowIsBoundary {
            steps.append(Step(id: 0,
                              title: "Move to Applications",
                              detail: "Run from anywhere else, macOS hides the arrow.",
                              done: Bundle.main.bundlePath.hasPrefix("/Applications/"),
                              actionTitle: "Show in Finder",
                              action: { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }))
            steps.append(Step(id: 1,
                              title: "Allow Accessibility",
                              detail: "So Hadrian's Wall can see where your icons sit.",
                              done: AXIsProcessTrusted(),
                              actionTitle: "Allow…",
                              action: HidingStatus.openAccessibilitySettings))
        }
        steps.append(Step(id: 2,
                          title: "Hide your first icon",
                          detail: (status.arrowIsBoundary
                                   ? "⌘-drag an icon left of the arrow, then click the arrow."
                                   : "⌘-drag an icon left of the divider, then click the arrow."),
                          done: Preferences.hasHiddenIcons))
        return steps
    }

    static var isComplete: Bool { steps.allSatisfy(\.done) }
}

// View state. Settings themselves live in Preferences; this only tells SwiftUI
// to redraw when they change, wherever the change came from.
final class SettingsModel: ObservableObject {
    @Published var pane: SettingsPane = .general
    @Published private(set) var status = HidingStatus.current
    // Worked out once per refresh, not on every redraw.
    @Published private(set) var steps = Setup.steps
    var setupComplete: Bool { steps.allSatisfy(\.done) }
    @Published private(set) var isRecording = false

    private var keyMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var poll: Timer?

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
        steps = Setup.steps
        objectWillChange.send()
    }

    // Accessibility can be granted in System Settings without this app ever
    // becoming active, so while the window is open and setup is unfinished,
    // look again every second.
    func startPolling() {
        guard poll == nil, !setupComplete else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
            if self?.setupComplete == true { self?.stopPolling() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        poll = timer
    }

    func stopPolling() {
        poll?.invalidate()
        poll = nil
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
