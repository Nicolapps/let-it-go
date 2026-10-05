//
//  ContentView.swift
//  Let It Go
//

import SwiftUI

@Observable
final class ExtensionStatus {
    /// `nil` until Safari reports the extension's state.
    var isEnabled: Bool?
}

struct ContentView: View {
    var status: ExtensionStatus
    var openSafariSettings: () -> Void

    @State private var openedSettings = false
    @AppStorage("redirectBase", store: UserDefaults(suiteName: appGroup)) private var redirectBase = "http://go"

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .shadow(color: .indigoGlow.opacity(0.6), radius: 40, y: 12)

            VStack(spacing: 14) {
                Text("Let It Go")
                    .font(.system(size: 36, weight: .bold))
                    .shadow(color: Color(hex: 0x0E0F33).opacity(0.55), radius: 10, y: 3)

                HStack(spacing: 8) {
                    Text("Redirect go/ to")
                        .foregroundStyle(.white.opacity(0.75))
                    RedirectTargetField(value: $redirectBase)
                }
                .font(.title3)
            }
            .padding(.top, 16)

            Spacer(minLength: 32)

            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 22) {
                    SetupStep(number: 1, isDone: openedSettings || status.isEnabled == true) {
                        Button(action: openSettings) {
                            Label("Open Safari Settings › *Extensions*", systemImage: "safari")
                                .font(.headline)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                    }

                    SetupStep(number: 2, isDone: status.isEnabled == true) {
                        StepText("Select *Let It Go*") {
                            SafariSnippet(action: openSettings) {
                                HStack(spacing: 8) {
                                    ReplicaCheckbox()
                                    Image(nsImage: NSApp.applicationIconImage)
                                        .resizable()
                                        .frame(width: 28, height: 28)
                                    Text("Let It Go")
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }

                    SetupStep(number: 3, isDone: false) {
                        StepText("Click *Edit Websites…*") {
                            SafariSnippet(action: openSettings) {
                                ReplicaButton { Text("Edit Websites…") }
                            }
                        }
                    }

                    SetupStep(number: 4, isDone: false) {
                        StepText("Choose *Allow* for your search engine") {
                            SafariSnippet(action: openSettings) {
                                HStack(spacing: 6) {
                                    Image(systemName: "globe")
                                        .opacity(0.6)
                                    Text("google.com")
                                    Spacer()
                                    ReplicaButton {
                                        HStack(spacing: 18) {
                                            Text("Allow")
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.system(size: 9, weight: .bold))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 320, alignment: .leading)

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 32)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                AuroraBackground()
                Snowfall()
            }
            .ignoresSafeArea()
        }
        // Dragging anywhere that isn't a control moves the window, and clicking
        // ends an edit of the redirect target.
        .contentShape(.rect)
        .gesture(WindowDragGesture())
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
        .environment(\.colorScheme, .dark)
        .animation(.smooth, value: status.isEnabled)
        .animation(.smooth, value: openedSettings)
    }

    private func openSettings() {
        openedSettings = true
        openSafariSettings()
    }
}

/// The redirect target. Return or clicking away saves it, Escape puts the old
/// value back. A save is confirmed with a checkmark; an invalid value shakes the
/// field and shows a red cross until it's edited.
private struct RedirectTargetField: View {
    @Binding var value: String

    private enum Feedback { case saved, invalid }

    @State private var draft = ""
    @State private var feedback: Feedback?
    @State private var saveCount = 0
    @State private var shakeCount = 0
    @FocusState private var isFocused: Bool
    @State private var appearance = SystemAppearance()

    var body: some View {
        let isDark = appearance.isDark
        // Drawn by hand so it can follow the system appearance in this always-dark
        // window, like the Safari replicas below.
        TextField("http://go", text: $draft)
            .textFieldStyle(.plain)
            .foregroundStyle(isDark ? .white : .black)
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(isDark ? Color(hex: 0x1E1E22) : .white, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isDark ? .white.opacity(0.12) : .black.opacity(0.1))
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.6), lineWidth: 3)
                        .padding(-2)
                }
            }
            .focused($isFocused)
            .onSubmit(commit)
            // There's nothing else to tab to, so focus wouldn't change on its own.
            .onKeyPress(keys: [.tab, "\u{19}"]) { _ in
                commit()
                return .handled
            }
            .onExitCommand {
                draft = value
                isFocused = false
            }
            .overlay(alignment: .trailing) {
                Group {
                    switch feedback {
                    case .saved:
                        Image(systemName: "checkmark").foregroundStyle(isDark ? .mint : .green)
                    case .invalid:
                        Image(systemName: "xmark").foregroundStyle(.red)
                    case nil:
                        EmptyView()
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.trailing, 9)
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)
            }
            .frame(width: 200)
            .keyframeAnimator(initialValue: 0, trigger: shakeCount) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-8, duration: 0.06)
                    LinearKeyframe(7, duration: 0.07)
                    LinearKeyframe(-5, duration: 0.07)
                    LinearKeyframe(3, duration: 0.06)
                    LinearKeyframe(0, duration: 0.05)
                }
            }
            .onAppear { draft = value }
            .onChange(of: draft) { _, newDraft in
                // Saving also rewrites the draft, which shouldn't hide its checkmark.
                if feedback == .invalid || newDraft != value { feedback = nil }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .task(id: saveCount) {
                guard feedback == .saved else { return }
                do {
                    try await Task.sleep(for: .seconds(1.5))
                    feedback = nil
                } catch {}
            }
            .animation(.smooth(duration: 0.2), value: feedback)
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != value else {
            draft = value
            return
        }
        guard Self.isValid(trimmed) else {
            feedback = .invalid
            shakeCount += 1
            return
        }
        value = trimmed
        draft = trimmed
        feedback = .saved
        saveCount += 1
        isFocused = false
    }

    /// Accepts what the extension's `normalizeBase` can turn into a redirect:
    /// a bare host like `go` or `go.example.com`, or an http(s) URL, with no
    /// query or fragment.
    private static func isValid(_ base: String) -> Bool {
        guard !base.isEmpty, !base.contains(where: \.isWhitespace) else { return false }
        let withScheme = base.contains("://") ? base : "http://" + base
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), !host.isEmpty
        else { return false }
        return url.query == nil && url.fragment == nil
    }
}

/// One row of the setup checklist: a numbered glass badge that turns into a
/// checkmark once the step is done.
private struct SetupStep<Content: View>: View {
    var number: Int
    var isDone: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .stepTitle, spacing: 14) {
            ZStack {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.mint)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(number)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 32, height: 32)
            .glassEffect(.clear, in: .circle)

            content
        }
    }
}

private extension VerticalAlignment {
    /// The middle of a step's first line, which its badge lines up with.
    enum StepTitle: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }

    static let stepTitle = VerticalAlignment(StepTitle.self)
}

/// A step's instruction above a replica of the Safari Settings control it
/// refers to.
private struct StepText<Snippet: View>: View {
    var title: LocalizedStringKey
    @ViewBuilder var snippet: Snippet

    init(_ title: LocalizedStringKey, @ViewBuilder snippet: () -> Snippet) {
        self.title = title
        self.snippet = snippet()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .alignmentGuide(.stepTitle) { $0[VerticalAlignment.center] }
            snippet
        }
    }
}

/// A cut-out of Safari Settings showing a control in the state it should end up
/// in. It follows the system appearance like Safari does, even though this
/// window is always dark, and clicking it opens Safari Settings.
private struct SafariSnippet<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var content: Content

    @State private var appearance = SystemAppearance()

    var body: some View {
        let isDark = appearance.isDark
        content
            .font(.system(size: 13))
            .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.85))
            .environment(\.colorScheme, isDark ? .dark : .light)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(isDark ? Color(hex: 0x1E1E22).opacity(0.85) : .white, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isDark ? .white.opacity(0.12) : .black.opacity(0.08))
            }
            .contentShape(.rect)
            .onTapGesture(perform: action)
    }
}

// Lookalikes of AppKit controls, drawn by hand because real ones would follow
// the window's dark appearance rather than the system's.

private struct ReplicaCheckbox: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.tint)
            .frame(width: 16, height: 16)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
}

private struct ReplicaButton<Label: View>: View {
    @ViewBuilder var label: Label

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        label
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(isDark ? .white.opacity(0.12) : .black.opacity(0.07), in: .rect(cornerRadius: 7))
    }
}

/// Tracks whether the system is in light or dark mode.
@Observable
private final class SystemAppearance {
    private(set) var isDark = true
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        observation = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] app, _ in
            MainActor.assumeIsolated {
                self?.isDark = app.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            }
        }
    }
}

// MARK: - Background

/// The app icon's gradient: deep navy at the top, a lavender glow in the middle
/// and a pink dusk in the bottom corner.
private struct AuroraBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.38], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Color(hex: 0x0E0F33), Color(hex: 0x1A1A55), Color(hex: 0x332F7D),
                Color(hex: 0x262668), .indigoGlow, Color(hex: 0x3B2D84),
                Color(hex: 0x6F80C2), Color(hex: 0x6A3F98), Color(hex: 0xC070B8),
            ]
        )
    }
}

/// A few slow, soft flakes drifting down behind the content.
private struct Snowfall: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Flake {
        var x, phase, speed, size, opacity, sway: Double
    }

    private let flakes: [Flake] = {
        var rng = SystemRandomNumberGenerator()
        return (0..<45).map { _ in
            Flake(
                x: .random(in: 0...1, using: &rng),
                phase: .random(in: 0...1, using: &rng),
                speed: .random(in: 0.02...0.06, using: &rng),
                size: .random(in: 1.5...4, using: &rng),
                opacity: .random(in: 0.15...0.55, using: &rng),
                sway: .random(in: 4...14, using: &rng)
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for flake in flakes {
                    let progress = (flake.phase + t * flake.speed).truncatingRemainder(dividingBy: 1)
                    let y = progress * (size.height + 20) - 10
                    let x = flake.x * size.width + sin(t * 0.6 + flake.phase * 10) * flake.sway
                    let rect = CGRect(x: x, y: y, width: flake.size, height: flake.size)
                    context.fill(Circle().path(in: rect), with: .color(.white.opacity(flake.opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private extension Color {
    static let indigoGlow = Color(hex: 0x6A6AB8)

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview("Off") {
    let status = ExtensionStatus()
    status.isEnabled = false
    return ContentView(status: status, openSafariSettings: {})
        .frame(width: 440, height: 720)
}

#Preview("On") {
    let status = ExtensionStatus()
    status.isEnabled = true
    return ContentView(status: status, openSafariSettings: {})
        .frame(width: 440, height: 720)
}
