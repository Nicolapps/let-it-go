//
//  AppGroup.swift
//  Let It Go
//
//  Shared by the app and the extension, on macOS and iOS. Nonisolated because
//  the app target defaults to the main actor and Safari calls back off it.
//

nonisolated let extensionBundleIdentifier = "dev.ettlin.nicolas.letitgo.extension"

/// Where the app and the extension share the redirect target. iOS only takes
/// `group.` IDs; the Mac keeps the team-prefixed one, which Developer ID can
/// sign without a provisioning profile.
#if os(iOS)
nonisolated let appGroup = "group.dev.ettlin.nicolas.letitgo"
#else
nonisolated let appGroup = "W47E2LS5Y9.dev.ettlin.nicolas.letitgo"
#endif
