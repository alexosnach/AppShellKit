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

    /// `true` while `perform(_:)` runs a command. Then a call with an unknown
    /// tab id is recorded as a failure instead of trapping.
    @ObservationIgnored private var isPerforming = false

    /// The first unknown tab id met while performing a command.
    @ObservationIgnored private var performFailure: UnknownTabError?

    /// - Parameters:
    ///   - tabIDs: Tab identifiers in display order. The first one is selected at launch.
    ///   - deepLinkHandlers: Handlers for `open(_:)`, asked in order.
    /// - Precondition: Identifiers are unique. A duplicate traps when this
    ///   initializer is called (fail fast): it is a programmer error, not a user error.
    ///
    /// An empty `tabIDs` does not trap: `selectedTab` becomes `""` and no tab
    /// can be selected. `RootTabView` itself requires at least one tab.
    /// Nothing to clean up. Declared `nonisolated` so freeing the object never
    /// hops to the main actor: on iOS 26.0 that hop (an isolated deinit) can
    /// corrupt the heap when the last reference goes away outside a Swift task,
    /// for example in an XCTest method.
    nonisolated deinit {}

    public init(tabIDs: [String], deepLinkHandlers: [any DeepLinkHandler] = []) {
        selectedTab = tabIDs.first ?? ""
        stacks = Dictionary(uniqueKeysWithValues: tabIDs.map { ($0, StackRouter()) })
        self.deepLinkHandlers = deepLinkHandlers
    }

    /// Returns the stack of a tab.
    ///
    /// - Precondition: A tab with this `id` exists. Called directly with an
    ///   unknown id, this traps: it is a programmer error. Inside a command run
    ///   by `perform(_:)`, it instead fails that command (see `perform(_:)`).
    public func stack(for tabID: String) -> StackRouter {
        guard let stack = stacks[tabID] else {
            guard isPerforming else { preconditionFailure("No tab with id '\(tabID)'") }
            recordFailure(tabID)
            return StackRouter()   // detached and discarded: the command is rolled back
        }
        return stack
    }

    /// Selects a tab.
    ///
    /// - Precondition: A tab with this `id` exists. Called directly with an
    ///   unknown id, this traps: it is a programmer error. Inside a command run
    ///   by `perform(_:)`, it instead fails that command (see `perform(_:)`).
    public func select(_ tabID: String) {
        guard stacks[tabID] != nil else {
            guard isPerforming else { preconditionFailure("No tab with id '\(tabID)'") }
            recordFailure(tabID)
            return
        }
        selectedTab = tabID
    }

    private func recordFailure(_ tabID: String) {
        if performFailure == nil { performFailure = UnknownTabError(tabID: tabID) }
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
    /// The command runs as a whole or not at all. If it throws, or names a tab
    /// that doesn't exist (`UnknownTabError`), every change it made — the
    /// selected tab, the stacks, the modal — is put back, and the failure is
    /// returned. Nothing crashes, so commands built from untrusted input are safe.
    ///
    /// An unknown tab id doesn't stop the command: the rest of it still runs
    /// (pushes onto an unknown tab go to a throwaway stack) and is then rolled
    /// back. Check what you can before changing anything, and keep side effects
    /// outside the router out of commands. A nested `perform` is rolled back on
    /// its own; the outer command fails only if it throws that result.
    ///
    /// Traps in your own code (a force unwrap, an out-of-range index) are not
    /// errors and can't be caught: keep commands and handlers free of them.
    ///
    /// The library writes nothing to the console or the system log. Because
    /// every command goes through here, this is also the one place an app would
    /// hook its own logging or analytics, if it wants any.
    @discardableResult
    public func perform(_ command: any NavigationCommand) -> Result<Void, any Error> {
        let saved = savedState()
        let wasPerforming = isPerforming
        let outerFailure = performFailure
        isPerforming = true
        performFailure = nil
        defer {
            isPerforming = wasPerforming
            performFailure = outerFailure
        }

        do {
            try command.execute(on: self)
        } catch {
            restore(saved)
            return .failure(error)
        }
        if let failure = performFailure {
            restore(saved)
            return .failure(failure)
        }
        return .success(())
    }

    /// Everything a command can change, as values.
    private struct SavedState {
        let selectedTab: String
        let paths: [String: NavigationPath]
        let modal: PresentedModal?
        let modalPath: NavigationPath?
    }

    private func savedState() -> SavedState {
        SavedState(
            selectedTab: selectedTab,
            paths: stacks.mapValues(\.path),
            modal: modal,
            modalPath: modal?.stack.path
        )
    }

    /// Puts back only what changed, so screens that weren't touched don't redraw.
    private func restore(_ saved: SavedState) {
        if selectedTab != saved.selectedTab { selectedTab = saved.selectedTab }
        for (id, path) in saved.paths where stacks[id]?.path != path { stacks[id]?.path = path }
        if modal?.id != saved.modal?.id { modal = saved.modal }
        if let path = saved.modalPath, saved.modal?.stack.path != path { saved.modal?.stack.path = path }
    }

    /// Opens a deep link: the single entry point for links from any source.
    ///
    /// URL schemes and universal links arrive here automatically (`RootTabView`
    /// uses `onOpenURL` and reports the result to its `onDeepLink`). Push
    /// notifications, attribution SDKs and other sources call this method
    /// themselves with the URL they received.
    ///
    /// Never crashes: links are untrusted input. The first handler that
    /// returns a command — or throws — decides the result.
    ///
    /// - Returns: `.handled` if the navigation was performed, `.unhandled` if
    ///   no handler recognized the link, `.failed(error)` if a handler rejected
    ///   it or its command failed. In both non-handled cases nothing changed.
    @discardableResult
    public func open(_ url: URL) -> DeepLinkResult {
        for handler in deepLinkHandlers {
            let command: (any NavigationCommand)?
            do {
                command = try handler.command(for: url)
            } catch {
                return .failed(error)
            }
            guard let command else { continue }
            switch perform(command) {
            case .success: return .handled
            case .failure(let error): return .failed(error)
            }
        }
        return .unhandled
    }
}
