//
//  ContentView.swift
//  Let It Go
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    var status: ExtensionStatus
    var openSafariSettings: () -> Void

    @State private var openedSettings = false
    @AppStorage("redirectBase", store: UserDefaults(suiteName: appGroup)) private var redirectBase = "http://go"

    #if os(macOS)
    /// The window is always dark, so its environment can't tell.
    @State private var appearance = SystemAppearance()
    private var systemIsDark: Bool { appearance.isDark }
    #else
    /// Read above the dark override below, so it's still the system's.
    @Environment(\.colorScheme) private var systemColorScheme
    private var systemIsDark: Bool { systemColorScheme == .dark }
    #endif

    var body: some View {
        page
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    AuroraBackground()
                    Snowfall()
                }
                .ignoresSafeArea()
            }
            .contentShape(.rect)
            #if os(macOS)
            // Dragging anywhere that isn't a control moves the window, and clicking
            // ends an edit of the redirect target.
            .gesture(WindowDragGesture())
            .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
            #else
            // Tapping anywhere that isn't a control ends an edit of the redirect
            // target.
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            #endif
            .environment(\.systemIsDark, systemIsDark)
            .environment(\.colorScheme, .dark)
            .animation(.smooth, value: status.isEnabled)
            .animation(.smooth, value: openedSettings)
            .animation(.smooth, value: allowsSearchEngine)
    }

    @ViewBuilder
    private var page: some View {
        #if os(macOS)
        content
        #else
        // The checklist doesn't fit smaller iPhones, or any in landscape.
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        #endif
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            AppIcon()
                .frame(width: Self.iconSize, height: Self.iconSize)
                .shadow(color: .indigoGlow.opacity(0.6), radius: 40, y: 12)

            VStack(spacing: 28) {
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

            GlassContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 22) {
                    setupSteps
                }
            }
            .frame(maxWidth: 320, alignment: .leading)

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 32)
    }

    #if os(macOS)
    private static let iconSize: CGFloat = 112
    #else
    /// The Mac icon has a transparent margin around its artwork; this one doesn't.
    private static let iconSize: CGFloat = 92
    #endif

    /// Mirrors Safari Settings on the Mac, and the extension's page in the
    /// Settings app on iOS, where the steps happen.
    @ViewBuilder
    private var setupSteps: some View {
        SetupStep(number: 1, isDone: openedSettings || status.isEnabled == true) {
            Button(action: openSettings) {
                Group {
                    #if os(macOS)
                    Label("Open Safari Settings › *Extensions*", systemImage: "safari")
                    #else
                    // Opens straight to the extension's page.
                    Label("Open *Let It Go* in Settings", systemImage: "gear")
                    #endif
                }
                .font(.headline)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
            .glassButtonStyle()
            .controlSize(.extraLarge)
        }

        #if os(macOS)
        SetupStep(number: 2, isDone: status.isEnabled == true) {
            StepText("Select the checkbox next to *Let It Go*") {
                SafariSnippet {
                    // Measured on Safari's list: a 16 pt checkbox, 6 pt gap, icon
                    // artwork 28 pt wide (the image has transparent margins, so
                    // its frame is 34 pt), then 13 pt text 7 pt further.
                    HStack(spacing: 3) {
                        ReplicaCheckbox()
                        AppIcon()
                            .frame(width: 34, height: 34)
                            .padding(.vertical, -3)
                        Text("Let It Go")
                    }
                }
            }
        }

        // Clicking Edit Websites… leaves no trace, so step 3 ticks along
        // with step 4.
        SetupStep(number: 3, isDone: allowsSearchEngine) {
            StepText("Click *Edit Websites…*") {
                SafariSnippet {
                    ReplicaButton { Text("Edit Websites…") }
                        .controlSize(.small)
                }
            }
        }

        SetupStep(number: 4, isDone: allowsSearchEngine) {
            StepText("Choose *Allow* for your search engine") {
                SafariSnippet {
                    HStack(spacing: 6) {
                        // Safari shows the site's favicon once it has one, inset
                        // on a white disc.
                        Image(.googleLogo)
                            .resizable()
                            .frame(width: 11, height: 11)
                            .frame(width: 16, height: 16)
                            .background(.white, in: .circle)
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
        #else
        SetupStep(number: 2, isDone: status.isEnabled == true) {
            StepText("Turn on *Allow Extension*") {
                SafariSnippet {
                    HStack {
                        Text("Allow Extension")
                        Spacer()
                        ReplicaSwitch()
                    }
                }
            }
        }

        // Opening a website's permission leaves no trace, so step 3 ticks along
        // with step 4.
        SetupStep(number: 3, isDone: allowsSearchEngine) {
            StepText("Tap your search engine") {
                SafariSnippet {
                    HStack(spacing: 8) {
                        // Settings shows the site's favicon once it has one, inset on
                        // a white disc.
                        Image(.googleLogo)
                            .resizable()
                            .frame(width: 13, height: 13)
                            .frame(width: 20, height: 20)
                            .background(.white, in: .circle)
                        Text("google.com")
                        Spacer()
                        Text("Ask")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }

        SetupStep(number: 4, isDone: allowsSearchEngine) {
            StepText("Choose *Allow*") {
                SafariSnippet {
                    HStack {
                        Text("Allow")
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        #endif
    }

    /// Only trusted while the extension is on, since it can't report changes
    /// made while it's off.
    private var allowsSearchEngine: Bool {
        status.isEnabled == true && status.allowsSearchEngine
    }

    private func openSettings() {
        openedSettings = true
        openSafariSettings()
    }
}

/// The redirect target. Return or clicking away saves it, Escape (on the Mac)
/// puts the old value back. A save is confirmed with a checkmark; an invalid
/// value shakes the field and shows a red cross until it's edited.
private struct RedirectTargetField: View {
    @Binding var value: String

    private enum Feedback { case saved, invalid }

    @State private var draft = ""
    @State private var feedback: Feedback?
    @State private var saveCount = 0
    @State private var shakeCount = 0
    @FocusState private var isFocused: Bool
    @Environment(\.systemIsDark) private var isDark

    var body: some View {
        // Drawn by hand so it can follow the system appearance in this always-dark
        // window, like the Safari replicas below.
        TextField("http://go", text: $draft)
            .textFieldStyle(.plain)
            .foregroundStyle(isDark ? .white : .black)
            // Otherwise the selection and cursor are drawn for the dark window.
            .environment(\.colorScheme, isDark ? .dark : .light)
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            #endif
            .padding(.horizontal, 8)
            .frame(height: Self.height)
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
            #if os(macOS)
            .onExitCommand {
                draft = value
                isFocused = false
            }
            #endif
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
            // Narrower on small iPhones.
            .frame(minWidth: 140, maxWidth: 200)
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
            // Saved from the extension's toolbar popover.
            .onChange(of: value) { _, newValue in
                if !isFocused { draft = newValue }
            }
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

    #if os(macOS)
    private static let height: CGFloat = 30
    #else
    /// Easier to tap.
    private static let height: CGFloat = 36
    #endif

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
            .clearGlassCircle()

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

/// A cut-out of Safari Settings (the Settings app on iOS) showing a control in
/// the state it should end up in. It follows the system appearance like Safari
/// does, even though this window is always dark. Clicking it blurs the replica
/// for a moment behind a reminder that the real control is elsewhere.
private struct SafariSnippet<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.systemIsDark) private var isDark
    @State private var showsHint = false
    @State private var hintCount = 0

    #if os(macOS)
    private static var fontSize: CGFloat { 13 }
    private static var minHeight: CGFloat { 40 }
    private static var hint: LocalizedStringKey { "This is just a preview, do this in Safari" }
    #else
    private static var fontSize: CGFloat { 15 }
    private static var minHeight: CGFloat { 44 }
    private static var hint: LocalizedStringKey { "This is just a preview, do this in Settings" }
    #endif

    var body: some View {
        content
            .font(.system(size: Self.fontSize))
            .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.85))
            .environment(\.colorScheme, isDark ? .dark : .light)
            .blur(radius: showsHint ? 6 : 0)
            .opacity(showsHint ? 0.35 : 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: .leading)
            .overlay {
                if showsHint {
                    Text(Self.hint)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .black.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .background(isDark ? Color(hex: 0x1E1E22).opacity(0.85) : .white, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isDark ? .white.opacity(0.12) : .black.opacity(0.08))
            }
            .contentShape(.rect)
            .onTapGesture {
                showsHint = true
                hintCount += 1
            }
            // Each click restarts the countdown.
            .task(id: hintCount) {
                guard showsHint else { return }
                do {
                    try await Task.sleep(for: .seconds(3))
                    showsHint = false
                } catch {}
            }
            .animation(.smooth(duration: 0.3), value: showsHint)
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
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        let isDark = colorScheme == .dark
        let isSmall = controlSize == .small
        label
            .font(isSmall ? .system(size: 11) : nil)
            .padding(.horizontal, isSmall ? 16 : 12)
            .frame(height: isSmall ? 20 : 24)
            .background(
                isDark ? .white.opacity(0.12) : .black.opacity(0.07),
                in: .rect(cornerRadius: isSmall ? 6 : 7)
            )
    }
}

// Lookalikes of UIKit controls, for the same reason.

/// The iOS 26 switch, turned on.
private struct ReplicaSwitch: View {
    var body: some View {
        Capsule()
            .fill(.green)
            .frame(width: 48, height: 28)
            .overlay(alignment: .trailing) {
                Capsule()
                    .fill(.white)
                    .frame(width: 30, height: 24)
                    .padding(2)
            }
    }
}

/// Whether the system, rather than this always-dark window, is in dark mode.
nonisolated private struct SystemIsDarkKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var systemIsDark: Bool {
        get { self[SystemIsDarkKey.self] }
        set { self[SystemIsDarkKey.self] = newValue }
    }
}

/// The app's icon, as the system draws it.
private struct AppIcon: View {
    var body: some View {
        #if os(macOS)
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
        #else
        // UIKit has no way to get at the app's own icon.
        Image(.appIconImage)
            .resizable()
        #endif
    }
}

#if os(macOS)
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
#endif

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

    /// Kept in state so the parent re-rendering doesn't reshuffle the flakes.
    @State private var flakes: [Flake] = {
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

// MARK: - Glass

/// Groups glass shapes so they blend together on macOS 26 and later (iOS always
/// has glass); earlier systems have no glass and just show the content.
private struct GlassContainer<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            // Not `.bordered`: that's an AppKit button, which the window-wide drag
            // and tap gestures keep from being clicked, and which looks disabled
            // on this background.
            buttonStyle(FrostedButtonStyle())
        }
    }

    @ViewBuilder
    func clearGlassCircle() -> some View {
        if #available(macOS 26, *) {
            glassEffect(.clear, in: .circle)
        } else {
            background(.ultraThinMaterial, in: .circle)
        }
    }
}

/// Stands in for the glass button style before macOS 26, matching the frosted
/// step badges.
private struct FrostedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: .capsule)
            .overlay {
                Capsule().strokeBorder(.white.opacity(0.25))
            }
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
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
