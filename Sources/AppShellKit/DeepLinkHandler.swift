//
//  DeepLinkHandler.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import Foundation

/// Turns a deep link URL into a navigation command — or declines it.
///
/// Deep links come from many sources: URL schemes, universal links, push
/// notifications, attribution SDKs (AppsFlyer and the like), widgets. Each
/// source is a small adapter that extracts a `URL` and calls
/// `AppRouter.open(_:)`. From there on every link goes the same way:
///
/// ```
/// source → URL → DeepLinkHandler → NavigationCommand → AppRouter.perform
/// ```
///
/// Each feature owns the links for its own screens and provides its own
/// handler, so adding links never touches the skeleton (Open/Closed).
/// Handlers are asked in order; the first one that returns a command wins
/// (Chain of Responsibility).
///
/// Return `nil` for a link this handler doesn't own, so the next handler is
/// asked. Throw for a link it owns but that is invalid (a missing or
/// malformed parameter): `AppRouter.open(_:)` stops there and returns
/// `.failed(error)`, so the app can tell the user or report it.
///
/// - Important: A deep link is **untrusted input**: anyone can craft one.
///   Validate every parameter, and only ever map links to navigation —
///   never to actions such as payments or deletion.
///
/// ```swift
/// struct HomeDeepLinks: DeepLinkHandler {
///     func command(for url: URL) -> (any NavigationCommand)? {
///         // myapp://home/detail/3
///         guard url.host() == "home" else { return nil }
///         …
///     }
/// }
/// ```
public protocol DeepLinkHandler {
    /// Returns a command for the URL, `nil` if this handler doesn't own it, or
    /// throws if it owns the link but the link is invalid.
    @MainActor func command(for url: URL) throws -> (any NavigationCommand)?
}

/// What happened to a deep link. Returned by `AppRouter.open(_:)` and passed
/// to `RootTabView`'s `onDeepLink`. Opening a link never crashes the app.
public nonisolated enum DeepLinkResult {
    /// A handler recognized the link and its navigation was performed.
    case handled
    /// No handler recognized the link. Nothing changed.
    case unhandled
    /// A handler recognized the link, but it was invalid or its navigation
    /// failed (for example an `UnknownTabError`). Nothing changed.
    case failed(any Error)
}

/// A ready-made command that presents a modal. Lets deep links and other
/// non-view code open modals without writing a command per modal (DRY).
public struct PresentModal<Destination: ModalDestination>: NavigationCommand {
    /// The modal to present.
    public let destination: Destination

    /// Creates a command that presents `destination`.
    public init(destination: Destination) {
        self.destination = destination
    }

    /// Presents the modal through `AppRouter.present(_:)`, replacing any modal on screen.
    public func execute(on router: AppRouter) {
        router.present(destination)
    }
}
