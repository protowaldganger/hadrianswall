//
//  StatusBarController.swift
//  Hadrian's Wall
//

import AppKit

// Owns the status items and decides WHEN to collapse or expand. HOW icons get
// hidden lives in the MenuBarEngine, picked per macOS version.
final class StatusBarController: MenuBarItemProvider {

    // MARK: - Items

    private let toggle = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let separator = NSStatusBar.system.statusItem(withLength: 1)
    private var alwaysHidden: NSStatusItem?

    var toggleItem: NSStatusItem { toggle }
    var separatorItem: NSStatusItem { separator }
    var alwaysHiddenItem: NSStatusItem? { alwaysHidden }

    private lazy var engine: MenuBarEngine = MenuBarEngineFactory.make(items: self)
    private let lineImage = NSImage(named: "ic_line")

    // MARK: - State

    private var autoHideTimer: Timer?
    private var hoverMonitor: Any?
    private var hoverDwellTimer: Timer?
    private var isToggling = false

    private var isCollapsed: Bool { engine.state == .collapsed }

    // True while the pointer is in any screen's menu bar band (between
    // visibleFrame.maxY and frame.maxY). A fullscreen space has no band.
    private var isMouseInMenuBar: Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            mouse.x >= screen.frame.minX && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY && mouse.y <= screen.frame.maxY
        }
    }

    // MARK: - Life cycle

    init() {
        configureButtons()
        // ⌘-dragging an item off the bar is remembered by macOS (autosaveName)
        // and would leave the app unreachable; these items are its only UI.
        toggle.isVisible = true
        separator.isVisible = true
        // Created now so an engine that does not use the separator (macOS 27)
        // takes it back out before it is ever drawn.
        _ = engine
        syncAlwaysHiddenItem()
        syncHoverMonitor()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(preferencesChanged), name: .prefsChanged, object: nil)
        center.addObserver(self, selector: #selector(syncAlwaysHiddenItem), name: .alwayHideToggle, object: nil)

        if Preferences.areSeparatorsHidden { hideSeparators() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.collapse()
        }
        scheduleAutoCollapse()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        autoHideTimer?.invalidate()
        hoverDwellTimer?.invalidate()
        if let hoverMonitor { NSEvent.removeMonitor(hoverMonitor) }
    }

    private func configureButtons() {
        if let button = separator.button {
            button.image = lineImage
            button.target = self
            button.action = #selector(separatorPressed(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Wall divider".localized)
        }
        if let button = toggle.button {
            button.target = self
            button.action = #selector(togglePressed(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateArrow()
        toggle.autosaveName = "wall_toggle"
        separator.autosaveName = "wall_divider"
    }

    // The arrow points the way a click will move the icons.
    private func updateArrow() {
        guard let button = toggle.button else { return }
        let collapsed = isCollapsed
        button.image = NSImage(named: collapsed == Constant.isUsingLTRLanguage ? "ic_expand" : "ic_collapse")
        button.setAccessibilityLabel((collapsed ? "Show hidden icons" : "Hide icons").localized)
    }

    // MARK: - Clicks

    @objc private func togglePressed(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        // VoiceOver's AXPress carries no event; the resolver maps that to .toggle.
        switch ExpandCollapseActionResolver.action(eventType: event?.type,
                                                   optionPressed: event?.modifierFlags.contains(.option) ?? false) {
        case .toggle: expandCollapseIfNeeded()
        case .contextMenu: showContextMenu(from: sender)
        case .toggleSeparators: toggleSeparators()
        }
    }

    @objc private func separatorPressed(_ sender: NSStatusBarButton) {
        showContextMenu(from: sender)
    }

    // A fresh menu per presentation, popped up below the button. performClick
    // would re-enter this button's own action and recurse; anchoring at the top
    // edge pushed the first row off screen.
    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item(Preferences.isAutoHide ? "Disable Auto Collapse" : "Enable Auto Collapse",
                          #selector(toggleAutoHide), key: "t"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.popUp(positioning: nil, at: .zero, in: button)
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title.localized, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openSettings() { SettingsWindow.show() }
    @objc private func toggleAutoHide() { Preferences.isAutoHide.toggle() }

    // MARK: - Collapse / expand

    func expandCollapseIfNeeded() {
        // Debounce: rapid clicks used to flash the Dock icon repeatedly.
        guard !isToggling else { return }
        isToggling = true
        isCollapsed ? expand() : collapse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isToggling = false
        }
    }

    private func collapse() {
        guard engine.isArrangementValid, !isCollapsed else {
            return scheduleAutoCollapse()
        }
        engine.collapse { [weak self] result in
            guard let self else { return }
            self.updateArrow()
            // The first-run checklist's last step: something actually hid.
            if result == .collapsed, (self.engine.hiddenAppCount ?? 1) > 0 {
                Preferences.hasHiddenIcons = true
            }
        }
    }

    private func expand() {
        guard isCollapsed else { return }
        engine.expand()
        updateArrow()
        scheduleAutoCollapse()
    }

    // MARK: - Separators and the always-hidden section

    private func toggleSeparators() {
        Preferences.areSeparatorsHidden ? showSeparators() : hideSeparators()
        if isCollapsed { expand() }
    }

    private func showSeparators() {
        Preferences.areSeparatorsHidden = false
        if !isCollapsed { engine.expand() }
        engine.updateAlwaysHiddenSection(enabled: Preferences.alwaysHiddenSectionEnabled, separatorHidden: false)
    }

    private func hideSeparators() {
        // An always-hidden divider on the wrong side would hide the wrong icons.
        guard !Preferences.alwaysHiddenSectionEnabled || engine.isAlwaysHiddenSeparatorPlaced else { return }
        Preferences.areSeparatorsHidden = true
        if !isCollapsed { engine.expand() }
        engine.updateAlwaysHiddenSection(enabled: Preferences.alwaysHiddenSectionEnabled, separatorHidden: true)
    }

    @objc private func syncAlwaysHiddenItem() {
        if let alwaysHidden {
            NSStatusBar.system.removeStatusItem(alwaysHidden)
            self.alwaysHidden = nil
        }
        guard Preferences.alwaysHiddenSectionEnabled else { return }
        let item = NSStatusBar.system.statusItem(withLength: 0)
        alwaysHidden = item
        engine.updateAlwaysHiddenSection(enabled: true, separatorHidden: false)
        item.button?.image = lineImage
        item.button?.appearsDisabled = true
        item.button?.setAccessibilityLabel("Always hidden divider".localized)
        item.autosaveName = "wall_always_hidden"
        item.isVisible = true
    }

    @objc private func screenParametersChanged() {
        // Re-apply to the live items, or a display hot-plug leaves a stale
        // length behind.
        let wasCollapsed = isCollapsed
        engine.invalidateLayout()
        if wasCollapsed && Preferences.areSeparatorsHidden {
            engine.updateAlwaysHiddenSection(enabled: Preferences.alwaysHiddenSectionEnabled, separatorHidden: true)
        }
    }

    @objc private func preferencesChanged() {
        scheduleAutoCollapse()
        syncHoverMonitor()
    }

    // MARK: - Auto collapse

    private func scheduleAutoCollapse() {
        autoHideTimer?.invalidate()
        guard Preferences.isAutoHide, !isCollapsed else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: Preferences.numberOfSecondForAutoHide, repeats: false) { [weak self] _ in
            guard let self, Preferences.isAutoHide else { return }
            // Never shut the bar mid-interaction or while Settings is open;
            // re-arm instead (each re-arm replaces the last timer).
            if self.isMouseInMenuBar || SettingsWindow.isVisible {
                self.scheduleAutoCollapse()
            } else {
                self.collapse()
            }
        }
        autoHideTimer?.tolerance = 0.5
    }

    // MARK: - Hover to expand

    // The global monitor exists only while the preference is on.
    private func syncHoverMonitor() {
        guard Preferences.hoverToExpand != (hoverMonitor != nil) else { return }
        if let hoverMonitor {
            NSEvent.removeMonitor(hoverMonitor)
            self.hoverMonitor = nil
            hoverDwellTimer?.invalidate()
            hoverDwellTimer = nil
        } else {
            hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                self?.pointerMoved()
            }
        }
    }

    private func pointerMoved() {
        guard isCollapsed && isMouseInMenuBar else {
            hoverDwellTimer?.invalidate()
            hoverDwellTimer = nil
            return
        }
        // A short dwell, so a pointer passing through does not expand the bar.
        guard hoverDwellTimer == nil else { return }
        hoverDwellTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.hoverDwellTimer = nil
            if self.isCollapsed && self.isMouseInMenuBar { self.expand() }
        }
    }
}
