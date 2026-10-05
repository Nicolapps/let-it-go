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

class ViewController: NSViewController {

    private let status = ExtensionStatus()

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

    @objc private func refreshState() {
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { state, error in
            DispatchQueue.main.async {
                self.status.isEnabled = state?.isEnabled
            }
        }
    }

    private func openSafariSettings() {
        SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier)
    }

}
