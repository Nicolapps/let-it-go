//
//  ViewController.swift
//  Let It Go (iOS)
//

import SafariServices
import SwiftUI
import UIKit

/// Hosts the same view as the Mac app. UIKit rather than a SwiftUI `App` so the
/// status bar can be light on the always-dark background while the rest of the
/// app still knows whether the system is in light or dark mode, which the
/// Settings replicas follow.
class ViewController: UIViewController {

    private let status = ExtensionStatus()

    /// Asks Safari for the extension's state ten times a second while the app is
    /// on screen, which on iPad can be next to Settings.
    private var pollTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(rootView: ContentView(status: status, openSafariSettings: { [weak self] in
            self?.openSafariSettings()
        }))
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshState), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshState() }
        }
        // Keeps ticking while the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pollTimer?.invalidate()
        pollTimer = nil
    }

    @objc private func refreshState() {
        status.refresh()
    }

    private func openSafariSettings() {
        // Opens Settings › Apps › Safari › Extensions › Let It Go.
        SFSafariSettings.openExtensionsSettings(forIdentifiers: [extensionBundleIdentifier]) { error in
            guard let error else { return }
            NSLog("Couldn't show the extension in Settings: %@", error.localizedDescription)
        }
    }

}
