//
//  LegacyLengthEngine.swift
//  Hadrian's Wall
//

import AppKit

// Hides icons by inflating the separator until everything to its left leaves the
// visible bar. macOS <= 26 reflows around any length, so the length only has to
// be large enough to cover the widest attached display.
final class LegacyLengthEngine: MenuBarEngine {
    private weak var items: MenuBarItemProvider?

    private let expandedLength: CGFloat = 20

    init(items: MenuBarItemProvider) {
        self.items = items
    }

    // Derived from the live length rather than stored, and compared with > rather
    // than ==, so the state survives the collapse length being recomputed while
    // collapsed.
    var state: MenuBarEngineState {
        guard let separator = items?.separatorItem else { return .expanded }
        return separator.length > expandedLength ? .collapsed : .expanded
    }

    private var collapsedLength: CGFloat {
        // The menubar replicates across every attached display, so the collapse
        // length must cover the WIDEST screen, not NSScreen.main (the focused one);
        // sizing from a narrower screen leaks hidden icons on wider displays.
        // frame.width, not visibleFrame: the menubar spans the full frame width.
        let screenWidth = NSScreen.screens.map { $0.frame.width }.max() ?? 1728
        // Keep collapse length bounded to avoid pathological layout/memory behavior;
        // macOS enforces a hard 10,000pt maximum on NSStatusItem.length.
        return max(500, min(screenWidth * 2, 10_000))
    }

    func collapse(completion: @escaping (CollapseResult) -> Void) {
        items?.separatorItem.length = collapsedLength
        completion(.collapsed)
    }

    func expand() {
        items?.separatorItem.length = expandedLength
    }

    func updateAlwaysHiddenSection(enabled: Bool, separatorHidden: Bool) {
        let length: CGFloat
        if separatorHidden {
            length = enabled ? collapsedLength : 0
        } else {
            length = enabled ? expandedLength : 0
        }
        items?.alwaysHiddenItem?.length = length
    }

    // The separator is what widens, so it must sit between the hidden icons and
    // the arrow, and the always-hidden separator further out still.
    var isArrangementValid: Bool {
        return MenuBarOrder.isItem(items?.separatorItem, onHiddenSideOf: items?.toggleItem)
    }

    var hiddenAppCount: Int? { nil }

    var isAlwaysHiddenSeparatorPlaced: Bool {
        return MenuBarOrder.isItem(items?.alwaysHiddenItem, onHiddenSideOf: items?.separatorItem)
    }

    func invalidateLayout() {
        guard state == .collapsed else { return }
        items?.separatorItem.length = collapsedLength
    }
}
