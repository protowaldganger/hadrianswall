//
//  SettingsView.swift
//  Hadrian's Wall
//
//  Quiet by design: one sidebar, a grey that slides to what you pick, and
//  nothing else around the settings. System colors only, so light, dark and
//  increased contrast all come for free. Shares its type scale, its sliding
//  grey and its footer with Pervitin.
//

import AppKit
import SwiftUI

// The visual language shared by every protowaldganger app.
enum Style {
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let raised = Color(nsColor: .controlBackgroundColor)
    static let well = Color.primary.opacity(0.04)
    static let track = Color.primary.opacity(0.08)
    static let hairline = Color.primary.opacity(0.08)
    static let ink = Color.primary.opacity(0.62)
    static let slide = Animation.spring(response: 0.3, dampingFraction: 0.86)

    static let title = Font.system(size: 24, weight: .semibold)
    static let body = Font.system(size: 13)
    static let detail = Font.system(size: 11)
    static let footer = Font.system(size: 11)
}

// A Binding straight onto Preferences; the model redraws when they change.
private func pref<Value>(_ get: @escaping () -> Value, _ set: @escaping (Value) -> Void) -> Binding<Value> {
    Binding(get: get, set: set)
}

struct SettingsView: View {
    static let size = CGSize(width: 640, height: 520)

    @ObservedObject var model: SettingsModel
    @Namespace var sidebarSelection

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Style.hairline).frame(width: 1)
            VStack(spacing: 0) {
                pane
                MakerFooter(name: Constant.appName, updates: UpdateCheck.shared)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.canvas)
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
                    .fill(model.status.isWorking && model.setupComplete ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(model.setupComplete ? model.status.title : "Finish setting up")
                    .font(Style.detail)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
            .onTapGesture { withAnimation(Style.slide) { model.pane = .menuBar } }
        }
        .padding(.top, 52)
        .padding(.horizontal, 10)
        .frame(width: 184)
        .background(Style.well)
    }

    private func sidebarItem(_ pane: SettingsPane) -> some View {
        let selected = model.pane == pane
        return Button {
            withAnimation(Style.slide) { model.pane = pane }
        } label: {
            HStack(spacing: 10) {
                LetterTile(letter: pane.letter, selected: selected)
                Text(pane.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundColor(selected ? .primary : Style.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Style.track)
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
                .font(Style.title)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .id(model.pane)
    }
}

// MARK: - General

// Each pane observes the model so a change made elsewhere (the status item's
// menu, another window) redraws it.
private struct GeneralPane: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var updates = UpdateCheck.shared

    private static let delays: [(Double, String)] = [(5, "5s"), (10, "10s"), (15, "15s"), (30, "30s"), (60, "1m")]

    var body: some View {
        VStack(spacing: 0) {
            Row("Open at login") {
                Switch(pref({ Preferences.isAutoStart }, { Preferences.isAutoStart = $0 }))
            }
            Row("Collapse automatically",
                detail: "Waits while the pointer is in the menu bar.") {
                Switch(pref({ Preferences.isAutoHide }, { Preferences.isAutoHide = $0 }))
            }
            if Preferences.isAutoHide {
                Row("After") {
                    Chips(options: Self.delays,
                          selection: pref({ Preferences.numberOfSecondForAutoHide }, { Preferences.numberOfSecondForAutoHide = $0 }))
                }
            }
            Row("Expand on hover",
                detail: "Rest the pointer in the menu bar for half a second.") {
                Switch(pref({ Preferences.hoverToExpand }, { Preferences.hoverToExpand = $0 }))
            }
            Row("Show Settings at launch") {
                Switch(pref({ Preferences.isShowPreference }, { Preferences.isShowPreference = $0 }))
            }
            Row("Check for updates",
                detail: "Once a day, asks GitHub for the newest release. Nothing else is sent.",
                divider: false) {
                Switch(Binding(get: { updates.isEnabled }, set: { updates.isEnabled = $0 }))
            }
        }
        .animation(Style.slide, value: Preferences.isAutoHide)
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
                 ? "⌘-drag icons left of the arrow to hide them, right of it to keep them."
                 : "⌘-drag icons left of the divider to hide them, right of it to keep them.")
                .font(Style.detail)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)

            if !model.setupComplete {
                Checklist(steps: model.steps)
                    .padding(.bottom, 6)
            } else if !status.isWorking {
                StatusCard(status: status)
                    .padding(.bottom, 6)
            }

            Row("Always-hidden section",
                detail: "Icons past a second divider stay hidden. ⌥-click the arrow to show them.",
                divider: status.arrowIsBoundary) {
                Switch(pref({ Preferences.alwaysHiddenSectionEnabled }, { Preferences.alwaysHiddenSectionEnabled = $0 }))
            }
            // Only macOS 27 can decide where a new app's icons go; before
            // that, macOS puts them on the hidden side and nothing can move them.
            if status.arrowIsBoundary {
                Row("New icons",
                    detail: "Where icons of newly installed apps start out.",
                    divider: false) {
                    Chips(options: [(true, "Visible"), (false, "Hidden")],
                          selection: pref({ Preferences.newIconsVisible }, { Preferences.newIconsVisible = $0 }))
                }
            }
        }
        .animation(Style.slide, value: model.setupComplete)
    }
}

// Three steps that tick themselves off. Shown until all are done.
private struct Checklist: View {
    let steps: [Setup.Step]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(step.done ? Color.green : Style.track)
                            .frame(width: 20, height: 20)
                        if step.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundColor(Style.ink)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(size: 13, weight: .medium))
                            .strikethrough(step.done, color: .secondary)
                            .foregroundColor(step.done ? .secondary : .primary)
                        if !step.done {
                            Text(step.detail)
                                .font(Style.detail)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    if !step.done, let title = step.actionTitle, let action = step.action {
                        Button(title, action: action)
                            .controlSize(.small)
                    }
                }
                .padding(.vertical, 6)
                .animation(Style.slide, value: step.done)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Style.well))
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
                    section("Always hidden", icons: ["cloud", "paperplane"], divider: true)
                        .transition(gone)
                }
                section("Hidden", icons: ["bolt", "music.note", "drop"], divider: !arrowIsBoundary)
                    .transition(gone)
            }
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(Style.slide) { collapsed.toggle() }
                    } label: {
                        Image(systemName: collapsed ? "chevron.left" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Style.track))
                    }
                    .buttonStyle(.plain)
                    .help((collapsed ? "Show hidden icons" : "Hide icons"))
                    ForEach(["wifi", "battery.75"], id: \.self) { glyph($0, faded: false) }
                    Text("9:41").font(.system(size: 12, weight: .medium).monospacedDigit())
                }
                .frame(height: 30)
                label("Visible")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Style.well)
                .frame(height: 30)
        }
    }

    private var gone: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.4, anchor: .trailing))
    }

    private func section(_ title: String, icons: [String], divider: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(icons, id: \.self) { glyph($0, faded: true) }
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

// Shown only when hiding cannot work at all on this Mac.
private struct StatusCard: View {
    let status: HidingStatus

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title).font(.system(size: 13, weight: .semibold))
                Text(status.detail)
                    .font(Style.detail)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if status == .needsAccessibility {
                Button("Allow…") { HidingStatus.openAccessibilitySettings() }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Style.well))
    }
}

// MARK: - Shortcut

private struct ShortcutPane: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Show or hide your icons from anywhere.")
                .font(Style.body)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                if model.isRecording {
                    Text("Type a shortcut…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(height: 34)
                } else if let keys = Preferences.globalKey?.keys, !keys.isEmpty {
                    ForEach(Array(keys.enumerated()), id: \.offset) { Keycap(text: $0.element) }
                } else {
                    Text("No shortcut")
                        .font(Style.body)
                        .foregroundColor(.secondary)
                        .frame(height: 34)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(model.isRecording ? Color.accentColor : Style.hairline,
                                  style: StrokeStyle(lineWidth: model.isRecording ? 1.5 : 1, dash: model.isRecording ? [4, 3] : []))
            )
            .contentShape(Rectangle())
            .onTapGesture { model.isRecording ? model.stopRecording() : model.startRecording() }

            HStack(spacing: 8) {
                Button(model.isRecording ? "Cancel" : "Record…") {
                    model.isRecording ? model.stopRecording() : model.startRecording()
                }
                .keyboardShortcut(.defaultAction)
                Button("Clear") { model.clearShortcut() }
                    .disabled(Preferences.globalKey == nil)
            }

            Text("Use at least one of ⌃ ⌥ ⇧ ⌘, or an F-key. Esc cancels, Delete clears.")
                .font(Style.detail)
                .foregroundColor(.secondary)
        }
        .animation(Style.slide, value: model.isRecording)
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
                    .fill(Style.raised)
                    .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Style.hairline)
            )
    }
}

// MARK: - About

private struct AboutPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Constant.appName).font(.system(size: 17, weight: .semibold))
                    Text("Hide menu bar icons behind a wall.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 28) {
                fact("0", "trackers")
                fact("0", "dependencies")
                fact("3", "menu bar items")
            }

            Text("Nothing leaves this Mac unless you turn on Check for updates.")
                .font(Style.detail)
                .foregroundColor(.secondary)
        }
    }

    private func fact(_ number: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(number).font(.system(size: 20, weight: .semibold).monospacedDigit())
            Text(caption).font(Style.detail).foregroundColor(.secondary)
        }
    }
}

// MARK: - Building blocks

// The same last line in every protowaldganger app.
struct MakerFooter: View {
    let name: String
    @ObservedObject var updates: UpdateCheck

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(name) \(version) · by protowaldganger")
            Spacer(minLength: 8)
            if let available = updates.available {
                Link("Update \(available) available", destination: updates.releasesPage)
                    .padding(.trailing, 14)
            }
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
        }
        .font(Style.footer)
        .foregroundColor(.secondary)
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Style.hairline).frame(height: 1)
        }
    }
}

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
                Text(title).font(Style.body)
                if let detail {
                    Text(detail)
                        .font(Style.detail)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(Style.hairline).frame(height: 1) }
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
                    withAnimation(Style.slide) { selection.wrappedValue = value }
                } label: {
                    Text(title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular).monospacedDigit())
                        .foregroundColor(selected ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Style.raised)
                                    .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 1)
                                    .matchedGeometryEffect(id: "chip", in: chipSelection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Style.track))
    }
}

private struct LetterTile: View {
    let letter: String
    let selected: Bool

    var body: some View {
        Text(letter)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(selected ? Style.canvas : Style.ink)
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.85) : Style.track)
            )
    }
}
