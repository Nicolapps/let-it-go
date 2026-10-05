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
                .frame(width: 144, height: 144)
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
                        Button {
                            openedSettings = true
                            openSafariSettings()
                        } label: {
                            Label("Open Safari Settings", systemImage: "safari")
                                .font(.headline)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                    }

                    SetupStep(number: 2, isDone: status.isEnabled == true) {
                        StepText(
                            title: "Turn on Let It Go",
                            detail: "Tick its checkbox in the Extensions tab."
                        )
                    }

                    SetupStep(number: 3, isDone: false) {
                        StepText(
                            title: "Allow your search engine",
                            detail: "Click Edit Websites… and set it to Allow."
                        )
                    }
                }
            }
            .frame(width: 300, alignment: .leading)

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
            // Clicking anywhere else ends an edit of the redirect target.
            .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
        }
        .environment(\.colorScheme, .dark)
        .animation(.smooth, value: status.isEnabled)
        .animation(.smooth, value: openedSettings)
    }
}

/// The redirect target, shown as a glass pill that turns into a text field when
/// clicked. Return or clicking away saves, Escape puts the old value back, and a
/// checkmark confirms the save. Nothing here takes keyboard focus on launch.
private struct RedirectTargetField: View {
    @Binding var value: String

    @State private var draft = ""
    @State private var isEditing = false
    @State private var saveCount = 0
    @State private var justSaved = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isEditing {
                    TextField("http://go", text: $draft)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onAppear { isFocused = true }
                        .onSubmit(commit)
                        .onExitCommand(perform: cancel)
                } else {
                    Text(value)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: justSaved ? "checkmark" : isEditing ? "return" : "pencil")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(justSaved ? AnyShapeStyle(.mint) : AnyShapeStyle(.white.opacity(0.55)))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(.horizontal, 14)
        .frame(width: 200, height: 36)
        .contentShape(.capsule)
        .glassEffect(isEditing ? .regular.tint(.white.opacity(0.06)) : .clear, in: .capsule)
        .overlay(alignment: .bottom) {
            Text("Saved. Safari picks it up next time you switch to it.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize()
                .offset(y: 24)
                .opacity(justSaved ? 1 : 0)
        }
        .gesture(TapGesture().onEnded(beginEditing), isEnabled: !isEditing)
        .pointerStyle(isEditing ? nil : .horizontalText)
        .accessibilityAddTraits(isEditing ? [] : .isButton)
        .onChange(of: isFocused) { _, focused in
            if !focused && isEditing { commit() }
        }
        .task(id: saveCount) {
            guard justSaved else { return }
            do {
                try await Task.sleep(for: .seconds(2.5))
                justSaved = false
            } catch {}
        }
        .animation(.smooth(duration: 0.25), value: isEditing)
        .animation(.smooth(duration: 0.3), value: justSaved)
    }

    private func beginEditing() {
        draft = value
        justSaved = false
        isEditing = true
    }

    private func commit() {
        isEditing = false
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != value else { return }
        value = trimmed
        justSaved = true
        saveCount += 1
    }

    private func cancel() {
        isEditing = false
    }
}

/// One row of the setup checklist: a numbered glass badge that turns into a
/// checkmark once the step is done.
private struct SetupStep<Content: View>: View {
    var number: Int
    var isDone: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 14) {
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

private struct StepText: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.65))
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
        .frame(width: 440, height: 600)
}

#Preview("On") {
    let status = ExtensionStatus()
    status.isEnabled = true
    return ContentView(status: status, openSafariSettings: {})
        .frame(width: 440, height: 600)
}
