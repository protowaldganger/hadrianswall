//
//  AccessibilityMenuBarInventory.swift
//  Hadrian's Wall
//

import AppKit
import ApplicationServices

// Lists other apps' status items through public Accessibility API: every running
// app's AXExtrasMenuBar children, with the owning bundle from the process.
// Needs the Accessibility permission, and does not work inside the App Sandbox
// (the sandbox denies the mach-lookup to com.apple.axserver even when the
// permission is granted), so only the non-sandboxed direct build uses it.
final class AccessibilityMenuBarInventory: MenuBarInventoryProviding {
    private static let messagingTimeout: Float = 0.1

    private var hasRequestedAuthorization = false

    var isAuthorized: Bool {
        return AXIsProcessTrusted()
    }

    // Shows the system prompt once per launch; asking on every collapse would
    // nag while the user is still in System Settings.
    func requestAuthorization() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // Accessibility round-trips to every app take a moment, so the walk runs off
    // the main thread.
    func snapshot(completion: @escaping ([MenuBarInventoryItem]) -> Void) {
        // Only app bundles own status items. Skipping the rest (dozens of WebKit
        // and XPC helpers, each of which would sit out the timeout) cuts the walk
        // from ~2.8s to ~1s.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID && $0.bundleURL?.pathExtension == "app" }
            .map { (pid: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier) }
        DispatchQueue.global(qos: .userInitiated).async {
            let items = Self.statusItems(of: apps)
            DispatchQueue.main.async { completion(items) }
        }
    }

    // One Accessibility round-trip per app. They run side by side, so the walk
    // costs about as long as the slowest app instead of the sum of all of them,
    // and a busy app no longer holds up the rest.
    private static func statusItems(of apps: [(pid: pid_t, bundleIdentifier: String?)]) -> [MenuBarInventoryItem] {
        var perApp = [[MenuBarInventoryItem]](repeating: [], count: apps.count)
        perApp.withUnsafeMutableBufferPointer { buffer in
            let slots = buffer
            DispatchQueue.concurrentPerform(iterations: apps.count) { index in
                slots[index] = Self.statusItems(pid: apps[index].pid, bundleIdentifier: apps[index].bundleIdentifier)
            }
        }
        return perApp.flatMap { $0 }
    }

    private static func statusItems(pid: pid_t, bundleIdentifier: String?) -> [MenuBarInventoryItem] {
        let element = AXUIElementCreateApplication(pid)
        // The default timeout is several seconds per app; one hung app then
        // stalled the collapse (measured: ~18s on a normal session).
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        var barValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &barValue) == .success,
              let bar = barValue, CFGetTypeID(bar) == AXUIElementGetTypeID() else { return [] }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return [] }
        return children.compactMap { child in
            Self.frame(of: child).map { MenuBarInventoryItem(bundleIdentifier: bundleIdentifier, frame: $0) }
        }
    }

    // Accessibility frames use a top-left origin, AppKit's bottom-left. Only the
    // horizontal position matters for sections, and x is the same in both.
    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef, let sizeValue = sizeRef,
              AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }
}
