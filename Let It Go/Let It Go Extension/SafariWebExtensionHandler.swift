//
//  SafariWebExtensionHandler.swift
//  Let It Go Extension
//
//  Created by Nicolas Ettlin on 2026-10-04.
//

import SafariServices
import os.log

/// Shared with the app, which stores the redirect target here.
let appGroup = "W47E2LS5Y9.dev.ettlin.nicolas.letitgo"

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem

        let profile: UUID?
        if #available(iOS 17.0, macOS 14.0, *) {
            profile = request?.userInfo?[SFExtensionProfileKey] as? UUID
        } else {
            profile = request?.userInfo?["profile"] as? UUID
        }

        let message: Any?
        if #available(iOS 15.0, macOS 11.0, *) {
            message = request?.userInfo?[SFExtensionMessageKey]
        } else {
            message = request?.userInfo?["message"]
        }

        os_log(.default, "Received message from browser.runtime.sendNativeMessage: %@ (profile: %@)", String(describing: message), profile?.uuidString ?? "none")

        let defaults = UserDefaults(suiteName: appGroup)

        // background.js reports which search engines it may run on, so the app
        // can tick off the "Edit Websites…" steps.
        if let message = message as? [String: Any], message["type"] as? String == "allowedOrigins" {
            defaults?.set(message["origins"] as? [String] ?? [], forKey: "allowedOrigins")
        }

        // Written by the app's "Redirect go/ to" field.
        let redirectBase = defaults?.string(forKey: "redirectBase")

        let response = NSExtensionItem()
        if #available(iOS 15.0, macOS 11.0, *) {
            response.userInfo = [ SFExtensionMessageKey: [ "redirectBase": redirectBase ] ]
        } else {
            response.userInfo = [ "message": [ "redirectBase": redirectBase ] ]
        }

        context.completeRequest(returningItems: [ response ], completionHandler: nil)
    }

}
