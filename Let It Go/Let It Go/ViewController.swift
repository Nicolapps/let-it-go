//
//  ViewController.swift
//  Let It Go
//
//  Created by Nicolas Ettlin on 2026-10-04.
//

import Cocoa
import SafariServices
import SwiftUI

class ViewController: NSViewController {

    private let status = ExtensionStatus()

    /// Asks Safari for the extension's state ten times a second while the window
    /// is up.
    private var pollTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingView = NSHostingView(rootView: ContentView(status: status, openSafariSettings: { [weak self] in
            self?.openSafariSettings()
        }))
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshState), name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        guard let window = view.window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // Don't start with the cursor in the redirect target field.
        view.window?.makeFirstResponder(nil)

        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func refreshState() {
        status.refresh()
    }

    private func openSafariSettings() {
        // Asked while Safari isn't running, Safari 18 launches but never brings
        // up its Settings. Launch it first and ask once it's done launching.
        if let safari = NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleIdentifier).first {
            showExtensionInSafariSettings(onceLaunched: safari)
            return
        }
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: safariBundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: safariURL, configuration: NSWorkspace.OpenConfiguration()) { safari, error in
            DispatchQueue.main.async {
                guard let safari else {
                    NSLog("Couldn't launch Safari: %@", error?.localizedDescription ?? "unknown error")
                    return
                }
                self.showExtensionInSafariSettings(onceLaunched: safari)
            }
        }
    }

    private let safariBundleIdentifier = "com.apple.Safari"
    private var launchObservation: NSKeyValueObservation?

    private func showExtensionInSafariSettings(onceLaunched app: NSRunningApplication) {
        // KVO calls this on whichever thread Safari's launch is reported on.
        // The app target defaults to main actor isolation, so without
        // `@Sendable` this closure would be main actor code and crash there.
        launchObservation = app.observe(\.isFinishedLaunching, options: [.initial]) { @Sendable [weak self] app, _ in
            guard app.isFinishedLaunching else { return }
            DispatchQueue.main.async {
                guard let self, self.launchObservation != nil else { return }
                self.launchObservation = nil
                self.showExtensionInSafariSettings(attemptsLeft: 10)
            }
        }
    }

    private func showExtensionInSafariSettings(attemptsLeft: Int) {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { @Sendable error in
            // Called off the main thread, so not main actor code either.
            guard let error else { return }
            // Safari can refuse while it's still loading its extensions, so give
            // it a few more tries. If it never comes around, at least Safari is up
            // and the user can open its Settings themselves.
            NSLog("Couldn't show the extension in Safari Settings: %@", error.localizedDescription)
            guard attemptsLeft > 1 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showExtensionInSafariSettings(attemptsLeft: attemptsLeft - 1)
            }
        }
    }

}
