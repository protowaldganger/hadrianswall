//
//  AppDelegate.swift
//  Hadrian's Wall
//

import AppKit

// No storyboard: the app is three status items and one Settings window, all
// built in code, so launch skips nib loading entirely.
@main
enum App {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var statusBarController: StatusBarController?

    private var hotKey: GlobalHotKey?

    // A plain value, separate from the side-effecting `register(defaults:)`
    // call, so the defaults are testable without creating status items.
    static let defaultPreferenceValues: [String: Any] = [
        UserDefaults.Key.isAutoStart: false,
        UserDefaults.Key.isShowPreference: false,
        UserDefaults.Key.isAutoHide: true,
        UserDefaults.Key.numberOfSecondForAutoHide: 10.0,
        UserDefaults.Key.areSeparatorsHidden: false,
        UserDefaults.Key.alwaysHiddenSectionEnabled: false,
        UserDefaults.Key.hoverToExpand: false,
        UserDefaults.Key.newIconsVisible: true,
        UserDefaults.Key.hasHiddenIcons: false
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else { return }
        UserDefaults.standard.register(defaults: Self.defaultPreferenceValues)
        NSApp.mainMenu = makeMainMenu()
        AutoStart.apply(enabled: Preferences.isAutoStart)
        statusBarController = StatusBarController()
        applyGlobalKey()
        UpdateCheck.shared.startIfEnabled()
        // Settings opens by itself only while setup is unfinished, on the
        // checklist, or when the user asked for it at every launch.
        if !Setup.isComplete {
            SettingsWindow.show(.menuBar)
        } else if Preferences.isShowPreference {
            SettingsWindow.show()
        }
    }

    // Opening the app again (Finder, Spotlight, Launchpad) brings up Settings,
    // the only thing a second launch of a menu bar utility can usefully mean.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.show()
        return false
    }

    // Re-reads the stored shortcut. Settings calls this after recording one.
    func applyGlobalKey() {
        hotKey = nil
        hotKey = Preferences.globalKey.flatMap {
            GlobalHotKey(keyCode: $0.keyCode, carbonModifiers: $0.carbonFlags) { [weak self] in
                self?.statusBarController?.expandCollapseIfNeeded()
            }
        }
    }

    @objc func showSettings(_ sender: Any?) {
        SettingsWindow.show()
    }

    @objc func showAbout(_ sender: Any?) {
        SettingsWindow.show(.about)
    }

    // MARK: - Launch helpers

    // A second launch would otherwise spawn a duplicate set of status items.
    // Hand the launch to the running copy (which then shows Settings) and quit.
    private func ensureSingleInstance() -> Bool {
        let current = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications.first {
            guard $0.bundleIdentifier == Bundle.main.bundleIdentifier,
                  $0.processIdentifier != current else { return false }
            #if DEBUG
            // Let a dev build run next to the installed copy.
            return $0.bundleURL == Bundle.main.bundleURL
            #else
            return true
            #endif
        }
        guard let existing = running else { return true }
        if let url = existing.bundleURL {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        NSApp.terminate(nil)
        return false
    }

    // Only visible while "Use the full menu bar" makes the app regular, but it
    // also gives the Settings window ⌘, ⌘W and ⌘Q.
    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(Constant.appName)", action: #selector(showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(Constant.appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit \(Constant.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")

        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }
}
