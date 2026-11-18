//
//  NavigationFlow.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// The routers a flow's factory receives, so it can inject them into view
/// models through `init` — the same way it injects the app's services.
///
/// The library owns the routers, the app owns the services; the factory is the
/// one place where both meet.
public struct NavigationContext {
    /// The stack of this flow: the tab's stack, or the modal's own stack.
    public let stack: StackRouter
    /// App-wide navigation: tabs, modals, commands, deep links.
    public let app: AppRouter

    /// The container creates contexts; create your own only in tests and previews.
    public init(stack: StackRouter, app: AppRouter) {
        self.stack = stack
        self.app = app
    }
}

/// Anything that lives inside its own navigation stack: a root screen plus the
/// screens reachable from it.
///
/// Shared by tabs (`TabDescriptor`) and modals (`ModalDestination`), so both
/// build their stacks the same way (DRY). Each of them adds only what is
/// specific to it (Interface Segregation): a tab adds a title and an icon,
/// a modal adds a presentation style.
///
/// The conforming type is the feature's **assembly**: it holds the services it
/// was given in `init` and builds every screen and view model of the flow.
public protocol NavigationFlow {
    /// The root screen type, chosen by the conforming type.
    associatedtype Root: View

    /// The routes inside this flow. Usually a feature-owned `enum`.
    associatedtype Route: Hashable

    /// The screen type built by the factory.
    associatedtype Screen: View

    /// Builds the root screen.
    ///
    /// Don't wrap it in a `NavigationStack`: the container provides one.
    /// Pass `context` routers and your services into the view model's `init`.
    /// The same routers are also available via `@Environment` for simple
    /// screens without a view model.
    @MainActor @ViewBuilder
    func makeRoot(context: NavigationContext) -> Root

    /// Factory: builds the screen for a route of this flow.
    ///
    /// Don't register `.navigationDestination` yourself: the container does it
    /// for `Route`, so a route can never be pushed without a screen.
    ///
    /// - Important: SwiftUI may call this many times. Let the screen own its
    ///   view model with `@State`, so the first instance is kept and the rest
    ///   are discarded. Do heavy work in `.task`, not in the view model's `init`.
    @MainActor @ViewBuilder
    func makeScreen(for route: Route, context: NavigationContext) -> Screen
}

/// Default for a flow that has no routes — only a root screen.
///
/// Declare `typealias Route = Never` and skip `makeScreen`: a `Never` route can't
/// be created, so no screen is ever needed and no dead code has to be written.
extension NavigationFlow where Route == Never {
    public func makeScreen(for route: Never, context: NavigationContext) -> EmptyView {}
}

extension NavigationFlow {
    /// The root with all of the flow's routes registered. Called by the container.
    ///
    /// Opens the existential: the container holds flows as `any …`, but here the
    /// concrete `Route` and `Screen` types are known, so
    /// `.navigationDestination(for:)` can be registered. The result is erased
    /// to `AnyView` once, at the stack root.
    @MainActor
    func makeStackContent(context: NavigationContext) -> AnyView {
        AnyView(
            makeRoot(context: context)
                .navigationDestination(for: Route.self) { route in
                    makeScreen(for: route, context: context)
                }
        )
    }
}
