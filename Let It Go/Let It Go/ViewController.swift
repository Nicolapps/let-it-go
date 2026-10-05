//
//  ViewController.swift
//  Let It Go
//
//  Created by Nicolas Ettlin on 2026-10-04.
//

import Cocoa
import SafariServices
import SwiftUI

let extensionBundleIdentifier = "dev.ettlin.nicolas.letitgo.extension"

/// Shared with the extension, which reads the redirect target from here.
let appGroup = "W47E2LS5Y9.dev.ettlin.nicolas.letitgo"

class ViewController: NSViewController {

    private let status = ExtensionStatus()

    /// Safari doesn't announce when the extension is turned on or off, so ask
    /// it every second while the window is up and the checklist updates while
    /// the user is still in Safari Settings.
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

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func refreshState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { state, error in
            DispatchQueue.main.async {
                if self.status.isEnabled != state?.isEnabled {
                    self.status.isEnabled = state?.isEnabled
                }
            }
        }

        // Written by the extension whenever its website access changes.
        let allowedOrigins = UserDefaults(suiteName: appGroup)?.stringArray(forKey: "allowedOrigins") ?? []
        if status.allowsSearchEngine != !allowedOrigins.isEmpty {
            status.allowsSearchEngine = !allowedOrigins.isEmpty
        }
    }

    private func openSafariSettings() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier)
    }

}
