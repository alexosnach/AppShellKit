//
//  AppRouter.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// App-wide navigation state: the selected tab and the stack of every tab.
///
/// Responsibilities are split (SRP):
/// - `StackRouter` owns a single stack;
/// - `AppRouter` owns the set of tabs and the selection between them.
///
/// In the Command pattern this type is both the **Receiver** (commands act on it)
/// and the **Invoker** (`perform(_:)` is the single entry point).
@MainActor @Observable
public final class AppRouter {
    /// The `id` of the selected tab. `TabView` binds to it directly.
    public internal(set) var selectedTab: String

    /// The stack of every tab, keyed by tab `id`. Created once and kept for the app's lifetime.
    private let stacks: [String: StackRouter]

    /// Deep link handlers, asked in order. Not observed: they never change.
    @ObservationIgnored private let deepLinkHandlers: [any DeepLinkHandler]

    /// - Parameters:
    ///   - tabIDs: Tab identifiers in display order. The first one is selected at launch.
    ///   - deepLinkHandlers: Handlers for `open(_:)`, asked in order.
    /// - Precondition: Identifiers are unique. A duplicate traps at launch
    ///   (fail fast): it is a programmer error, not a user error.
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
    public func select(_ tabID: String) {
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
    /// This is also the place for navigation logging and analytics: added once,
    /// it applies to every command.
    public func perform(_ command: any NavigationCommand) {
        print("▶︎ navigation:", command)
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
        print("⚠︎ unhandled deep link:", url)
        return false
    }
}
