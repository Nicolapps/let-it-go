//
//  ExtensionStatus.swift
//  Let It Go
//

import Foundation
import Observation
import SafariServices

@Observable
final class ExtensionStatus {
    /// `nil` until Safari reports the extension's state.
    var isEnabled: Bool?
    /// Whether the extension may run on at least one search engine, as last
    /// reported by the extension.
    var allowsSearchEngine = false

    @ObservationIgnored private var isFetchingState = false

    /// Safari doesn't announce when the extension is turned on or off, so the
    /// app calls this many times a second while it's on screen and the checklist
    /// updates while the user is still in Settings.
    func refresh() {
        // Polling this fast, Safari sometimes fails a request or answers them out
        // of order, which made the checklist flicker. Keep one request in flight
        // and hold on to the last known state when one fails.
        if !isFetchingState {
            isFetchingState = true
            Self.fetchIsEnabled { isEnabled in
                DispatchQueue.main.async {
                    self.isFetchingState = false
                    if let isEnabled, self.isEnabled != isEnabled {
                        self.isEnabled = isEnabled
                    }
                }
            }
        }

        // Written by the extension whenever its website access changes.
        let allowedOrigins = UserDefaults(suiteName: appGroup)?.stringArray(forKey: "allowedOrigins") ?? []
        if allowsSearchEngine != !allowedOrigins.isEmpty {
            allowsSearchEngine = !allowedOrigins.isEmpty
        }
    }

    /// Safari calls back on a background queue.
    nonisolated private static func fetchIsEnabled(_ completion: @escaping @Sendable (Bool?) -> Void) {
        #if os(macOS)
        SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { state, _ in
            completion(state?.isEnabled)
        }
        #else
        SFSafariExtensionManager.getStateOfExtension(withIdentifier: extensionBundleIdentifier) { state, _ in
            completion(state?.isEnabled)
        }
        #endif
    }
}
