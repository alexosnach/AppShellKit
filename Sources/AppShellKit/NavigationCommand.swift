//
//  NavigationCommand.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import Foundation

/// A navigation command: a request to navigate, packaged as a value (Command pattern).
///
/// The caller (Client) only knows *what* it wants: "open screen 3 in Home".
/// *How* to do it — which tab to select, what to push — is known only to the
/// command itself, so features don't depend on each other's internals.
///
/// A command is declared by the feature that owns the screen and lives next to
/// its code; it is that feature's public contract. New navigation means a new
/// command type, while `AppRouter` stays unchanged (Open/Closed).
///
/// Use it for navigation **across** tabs, from deep links and notifications.
/// Within a tab, `StackRouter.push(_:)` is enough.
///
/// ```swift
/// appRouter.perform(OpenHomeScreen(number: 3))
/// ```
public protocol NavigationCommand {
    /// Performs the navigation. Called by `AppRouter.perform(_:)`; don't call it directly.
    @MainActor func execute(on router: AppRouter)
}
