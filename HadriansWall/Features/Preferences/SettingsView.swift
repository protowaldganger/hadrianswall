//
//  SettingsView.swift
//  Hadrian's Wall
//
//  Quiet by design: one sidebar, a grey that slides to what you pick, and
//  nothing else around the settings. System colors only, so light, dark and
//  increased contrast all come for free.
//

import AppKit
import SwiftUI

private enum Palette {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let well = Color.primary.opacity(0.04)
    static let pill = Color.primary.opacity(0.08)
    static let hairline = Color.primary.opacity(0.08)
    static let ink = Color.primary.opacity(0.62)
    static let slide = Animation.spring(response: 0.32, dampingFraction: 0.86)
}

// A Binding straight onto Preferences; the model redraws when they change.
private func pref<Value>(_ get: @escaping () -> Value, _ set: @escaping (Value) -> Void) -> Binding<Value> {
    Binding(get: get, set: set)
}

struct SettingsView: View {
    static let size = CGSize(width: 640, height: 440)

    @ObservedObject var model: SettingsModel
    @Namespace var sidebarSelection

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.hairline).frame(width: 1)
            pane
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Palette.canvas)
        .ignoresSafeArea()
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsPane.allCases) { pane in
                sidebarItem(pane)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(model.status.isWorking ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(model.status.title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
            .onTapGesture { withAnimation(Palette.slide) { model.pane = .menuBar } }
        }
        .padding(.top, 52)
        .padding(.horizontal, 10)
        .frame(width: 184)
        .background(Palette.well)
    }

    private func sidebarItem(_ pane: SettingsPane) -> some View {
        let selected = model.pane == pane
        return Button {
            withAnimation(Palette.slide) { model.pane = pane }
        } label: {
            HStack(spacing: 10) {
                LetterTile(letter: pane.letter, selected: selected)
                Text(pane.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .primary : Palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Palette.pill)
                        .matchedGeometryEffect(id: "selection", in: sidebarSelection)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Panes

    private var pane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.pane.title)
                .font(.system(size: 22, weight: .semibold))
                .padding(.bottom, 14)
            Group {
                switch model.pane {
                case .general: GeneralPane(model: model)
                case .menuBar: MenuBarPane(model: model)
                case .shortcut: ShortcutPane(model: model)
                case .about: AboutPane()
                }
            }
            .transition(.opacity)
            Spacer(minLength: 0)
        }
        .padding(.top, 44)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(model.pane)
    }
}

// MARK: - General

// Each pane observes the model so a change made elsewhere (the status item's
// menu, another window) redraws it.
private struct GeneralPane: View {
    @ObservedObject var model: SettingsModel
    private static let delays: [(Double, String)] = [(5, "5s"), (10, "10s"), (15, "15s"), (30, "30s"), (60, "1m")]

    var body: some View {
        VStack(spacing: 0) {
            Row("Open at login".localized) {
                Switch(pref({ Preferences.isAutoStart }, { Preferences.isAutoStart = $0 }))
            }
            Row("Collapse automatically".localized,
                detail: "Waits while the pointer is in the menu bar.".localized) {
                Switch(pref({ Preferences.isAutoHide }, { Preferences.isAutoHide = $0 }))
            }
            if Preferences.isAutoHide {
                Row("After".localized) {
                    Chips(options: Self.delays,
                          selection: pref({ Preferences.numberOfSecondForAutoHide }, { Preferences.numberOfSecondForAutoHide = $0 }))
                }
            }
            Row("Expand on hover".localized,
                detail: "Rest the pointer in the menu bar for half a second.".localized) {
                Switch(pref({ Preferences.hoverToExpand }, { Preferences.hoverToExpand = $0 }))
            }
            Row("Use the full menu bar when expanded".localized,
                detail: "Hides the frontmost app's menus so every icon fits.".localized) {
                Switch(pref({ Preferences.useFullStatusBarOnExpandEnabled }, { Preferences.useFullStatusBarOnExpandEnabled = $0 }))
            }
            Row("Show Settings at launch".localized, divider: false) {
                Switch(pref({ Preferences.isShowPreference }, { Preferences.isShowPreference = $0 }))
            }
        }
        .animation(Palette.slide, value: Preferences.isAutoHide)
    }
}

// MARK: - Menu bar

private struct MenuBarPane: View {
    @ObservedObject var model: SettingsModel
    private var status: HidingStatus { model.status }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuBarDiagram(alwaysHidden: Preferences.alwaysHiddenSectionEnabled,
                           arrowIsBoundary: status.arrowIsBoundary)
                .padding(.bottom, 12)
            Text(status.arrowIsBoundary
                 ? "⌘-drag icons left of the arrow to hide them, right of it to keep them.".localized
                 : "⌘-drag icons left of the divider to hide them, right of it to keep them.".localized)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.bottom, 16)

            StatusCard(status: status)
                .padding(.bottom, 6)

            Row("Always-hidden section".localized,
                detail: "Icons past a second divider stay hidden. ⌥-click the arrow to show them.".localized) {
                Switch(pref({ Preferences.alwaysHiddenSectionEnabled }, { Preferences.alwaysHiddenSectionEnabled = $0 }))
            }
            if NotchOverflowController.hasNotch {
                Row("Notch items".localized,
                    detail: "Right-click the arrow to reach icons behind the notch.".localized,
                    divider: false) {
                    Switch(pref({ Preferences.notchOverflowEnabled }, { Preferences.notchOverflowEnabled = $0 }))
                }
            }
        }
    }
}

// A live sketch of the menu bar. Click its arrow to watch the icons go.
private struct MenuBarDiagram: View {
    let alwaysHidden: Bool
    let arrowIsBoundary: Bool
    @State var collapsed = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Spacer(minLength: 0)
            if !collapsed {
                if alwaysHidden {
                    section("Always hidden".localized, icons: ["cloud", "paperplane"], faded: true, divider: true)
                        .transition(gone)
                }
                section("Hidden".localized, icons: ["bolt", "music.note", "drop"], faded: true, divider: !arrowIsBoundary)
                    .transition(gone)
            }
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(Palette.slide) { collapsed.toggle() }
                    } label: {
                        Image(systemName: collapsed ? "chevron.left" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Palette.pill))
                    }
                    .buttonStyle(.plain)
                    .help((collapsed ? "Show hidden icons" : "Hide icons").localized)
                    ForEach(["wifi", "battery.75"], id: \.self) { glyph($0, faded: false) }
                    Text("9:41").font(.system(size: 12, weight: .medium).monospacedDigit())
                }
                .frame(height: 30)
                label("Visible".localized)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.well)
                .frame(height: 30)
        }
    }

    private var gone: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.4, anchor: .trailing))
    }

    private func section(_ title: String, icons: [String], faded: Bool, divider: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(icons, id: \.self) { glyph($0, faded: faded) }
                if divider {
                    Capsule().fill(Color.primary.opacity(0.35)).frame(width: 2, height: 14)
                }
            }
            .frame(height: 30)
            label(title)
        }
    }

    private func glyph(_ name: String, faded: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.primary.opacity(faded ? 0.4 : 0.85))
            .frame(width: 16)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .medium)).foregroundColor(.secondary)
    }
}

private struct StatusCard: View {
    let status: HidingStatus

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(status.isWorking ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title).font(.system(size: 13, weight: .semibold))
                Text(status.detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if status == .needsAccessibility {
                Button("Allow…".localized) { HidingStatus.openAccessibilitySettings() }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.well))
    }
}

// MARK: - Shortcut

private struct ShortcutPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Show or hide your icons from anywhere.".localized)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                if model.isRecording {
                    Text("Type a shortcut…".localized)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(height: 34)
                } else if let keys = Preferences.globalKey?.keys, !keys.isEmpty {
                    ForEach(Array(keys.enumerated()), id: \.offset) { Keycap(text: $0.element) }
                } else {
                    Text("No shortcut".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(height: 34)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(model.isRecording ? Color.accentColor : Palette.hairline,
                                  style: StrokeStyle(lineWidth: model.isRecording ? 1.5 : 1, dash: model.isRecording ? [4, 3] : []))
            )
            .contentShape(Rectangle())
            .onTapGesture { model.isRecording ? model.stopRecording() : model.startRecording() }

            HStack(spacing: 8) {
                Button(model.isRecording ? "Cancel".localized : "Record…".localized) {
                    model.isRecording ? model.stopRecording() : model.startRecording()
                }
                .keyboardShortcut(.defaultAction)
                Button("Clear".localized) { model.clearShortcut() }
                    .disabled(Preferences.globalKey == nil)
            }

            Text("Use at least one of ⌃ ⌥ ⇧ ⌘, or an F-key. Esc cancels, Delete clears.".localized)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .animation(Palette.slide, value: model.isRecording)
    }
}

private struct Keycap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .frame(minWidth: 34, minHeight: 34)
            .padding(.horizontal, text.count > 1 ? 8 : 0)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Palette.canvas)
                    .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Palette.hairline)
            )
    }
}

// MARK: - About

private struct AboutPane: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return String(format: "Version %@ (%@)".localized, short, build)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Constant.appName).font(.system(size: 17, weight: .semibold))
                    Text(version).font(.system(size: 12)).foregroundColor(.secondary)
                }
            }

            Text("A menu bar with nothing in the way.".localized)
                .font(.system(size: 13))

            HStack(spacing: 28) {
                fact("0", "network calls".localized)
                fact("0", "dependencies".localized)
                fact("3", "menu bar items".localized)
            }

            Text("Made by protowaldganger".localized)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private func fact(_ number: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(number).font(.system(size: 20, weight: .semibold).monospacedDigit())
            Text(caption).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }
}

// MARK: - Building blocks

private struct Row<Accessory: View>: View {
    let title: String
    let detail: String?
    let divider: Bool
    let accessory: Accessory

    init(_ title: String, detail: String? = nil, divider: Bool = true, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.detail = detail
        self.divider = divider
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(Palette.hairline).frame(height: 1) }
        }
    }
}

private struct Switch: View {
    let isOn: Binding<Bool>
    init(_ isOn: Binding<Bool>) { self.isOn = isOn }

    var body: some View {
        Toggle("", isOn: isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
    }
}

// Segmented choices where the grey slides to the pick, like the sidebar.
private struct Chips<Value: Hashable>: View {
    let options: [(Value, String)]
    let selection: Binding<Value>
    @Namespace var chipSelection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                let (value, title) = options[index]
                let selected = selection.wrappedValue == value
                Button {
                    withAnimation(Palette.slide) { selection.wrappedValue = value }
                } label: {
                    Text(title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular).monospacedDigit())
                        .foregroundColor(selected ? .primary : Palette.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Palette.canvas)
                                    .shadow(color: .black.opacity(0.10), radius: 1, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "chip", in: chipSelection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Palette.pill))
    }
}

private struct LetterTile: View {
    let letter: String
    let selected: Bool

    var body: some View {
        Text(letter)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(selected ? Palette.canvas : Palette.ink)
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.85) : Palette.pill)
            )
    }
}
