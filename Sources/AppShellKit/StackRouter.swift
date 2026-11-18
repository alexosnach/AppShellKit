//
//  StackRouter.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// The state of **one** navigation stack: a tab's stack or a modal's stack.
///
/// Single responsibility (SRP): store and mutate the stack. No analytics,
/// no persistence, no knowledge of other stacks.
///
/// Screens get it via `@Environment(StackRouter.self)` and never create it
/// themselves (DI), so the same screen works in any tab and inside a modal.
///
/// For navigation **across** tabs, use `AppRouter.perform(_:)` with a
/// `NavigationCommand`.
@MainActor @Observable
public final class StackRouter {
    /// The current stack. The container's `NavigationStack` binds to it directly.
    public var path = NavigationPath()

    /// Creates an empty stack. The container makes one per tab and per modal;
    /// create your own only in tests and previews.
    public init() {}

    /// Pushes a route onto the stack.
    ///
    /// The route must be of the flow's `Route` type: the container registers a
    /// screen only for that type. A route of any other type shows nothing.
    public func push(_ route: some Hashable) {
        path.append(route)
    }

    /// Goes back one screen. Does nothing at the root.
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Returns to the root screen of this stack.
    public func popToRoot() {
        path = NavigationPath()
    }
}
