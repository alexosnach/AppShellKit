//
//  AppRouter.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// App-wide navigation: the selected tab, the stack of every tab, the modal
/// on screen, and the entry points for commands and deep links.
///
/// Responsibilities are split (SRP):
/// - `StackRouter` owns a single stack;
/// - `AppRouter` owns everything above the stacks: tabs, the modal layer,
///   commands and deep links.
///
/// Screens get it via `@Environment(AppRouter.self)`; factories get it as
/// `NavigationContext.app` and pass it into view models.
///
/// In the Command pattern this type is both the **Receiver** (commands act on it)
/// and the **Invoker** (`perform(_:)` is the single entry point).
@MainActor @Observable
public final class AppRouter {
    /// The `id` of the selected tab. Read-only outside the library: change it with `select(_:)`.
    public internal(set) var selectedTab: String

    /// The stack of every tab, keyed by tab `id`. Created once and kept for the app's lifetime.
    private let stacks: [String: StackRouter]

    /// Deep link handlers, asked in order. Not observed: they never change.
    @ObservationIgnored private let deepLinkHandlers: [any DeepLinkHandler]

    /// - Parameters:
    ///   - tabIDs: Tab identifiers in display order. The first one is selected at launch.
    ///   - deepLinkHandlers: Handlers for `open(_:)`, asked in order.
    /// - Precondition: Identifiers are unique. A duplicate traps when this
    ///   initializer is called (fail fast): it is a programmer error, not a user error.
    ///
    /// An empty `tabIDs` does not trap: `selectedTab` becomes `""` and no tab
    /// can be selected. `RootTabView` itself requires at least one tab.
    public init(tabIDs: [String], deepLinkHandlers: [any DeepLinkHandler] = []) {
        selectedTab = tabIDs.first ?? ""
        stacks = Dictionary(uniqueKeysWithValues: tabIDs.map { ($0, StackRouter()) })
        self.deepLinkHandlers = deepLinkHandlers
    }

    /// Returns the stack of a tab.
    ///
    /// - Precondition: A tab with this `id` exists.
    public func stack(for tabID: String) -> StackRouter {
        guard let stack = stacks[tabID] else {
            preconditionFailure("No tab with id '\(tabID)'")
        }
        return stack
    }

    /// Selects a tab.
    ///
    /// - Precondition: A tab with this `id` exists.
    public func select(_ tabID: String) {
        precondition(stacks[tabID] != nil, "No tab with id '\(tabID)'")
        selectedTab = tabID
    }

    /// The modal on screen, or `nil`. `RootTabView` presents it above the tab bar.
    ///
    /// One level only (KISS): presenting a new modal replaces the current one.
    public private(set) var modal: PresentedModal?

    /// Presents a modal above everything, with its own navigation stack.
    ///
    /// Callable from any screen in any tab, at any depth, and from commands
    /// (deep links, notifications). The tabs' stacks are left untouched.
    public func present(_ destination: some ModalDestination) {
        modal = PresentedModal(destination: destination)
    }

    /// Dismisses the current modal. Does nothing if none is shown.
    public func dismiss() {
        modal = nil
    }

    /// Performs a navigation command. The single entry point for cross-tab
    /// navigation, deep links and push notifications.
    ///
    /// The library writes nothing to the console or the system log. Because
    /// every command goes through here, this is also the one place an app would
    /// hook its own logging or analytics, if it wants any.
    public func perform(_ command: any NavigationCommand) {
        command.execute(on: self)
    }

    /// Opens a deep link: the single entry point for links from any source.
    ///
    /// URL schemes and universal links arrive here automatically (`RootTabView`
    /// uses `onOpenURL`). Push notifications, attribution SDKs and other sources
    /// call this method themselves with the URL they received.
    ///
    /// - Returns: `true` if a handler recognized the link. Unknown links are
    ///   ignored: they are untrusted input and must never crash the app.
    @discardableResult
    public func open(_ url: URL) -> Bool {
        for handler in deepLinkHandlers {
            if let command = handler.command(for: url) {
                perform(command)
                return true
            }
        }
        return false
    }
}
