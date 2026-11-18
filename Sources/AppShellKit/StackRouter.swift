//
//  StackRouter.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// The navigation stack state of a **single** tab.
///
/// Single responsibility (SRP): store and mutate the stack. No analytics,
/// no persistence, no knowledge of other tabs.
///
/// Screens get it via `@Environment(StackRouter.self)` and never create it
/// themselves (DI), so the same screen works in any tab.
///
/// For navigation **across** tabs, use `AppRouter.perform(_:)` with a
/// `NavigationCommand`.
@MainActor @Observable
public final class StackRouter {
    /// The current stack. The `NavigationStack` in `RootTabView` binds to it directly.
    public var path = NavigationPath()

    /// Creates an empty stack. The container makes one per tab and per modal;
    /// create your own only in tests and previews.
    public init() {}

    /// Pushes a route onto the stack.
    ///
    /// A `.navigationDestination(for:)` for the route's type must be registered
    /// inside this tab, otherwise SwiftUI shows nothing.
    public func push(_ route: some Hashable) {
        path.append(route)
    }

    /// Goes back one screen. Does nothing at the root.
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Returns to the tab's root screen.
    public func popToRoot() {
        path = NavigationPath()
    }
}
