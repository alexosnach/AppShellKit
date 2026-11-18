//
//  ModalDestination.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// How a modal is presented.
///
/// `nonisolated`: plain data, usable from any actor (the module defaults to `MainActor`).
public nonisolated enum ModalStyle {
    /// A card that slides up and can be swiped down.
    case sheet
    /// Covers the whole screen and can't be swiped away. Closes via
    /// `AppRouter.dismiss()`, or when another modal replaces it (`AppRouter.present(_:)`).
    case fullScreen
}

/// Describes a modal: what to show, with its own navigation stack, and how.
///
/// A value of this type is **data**: it can be created anywhere — a screen,
/// a command, a deep link — and handed to `AppRouter.present(_:)`. The feature
/// that owns the modal declares the type next to its code.
///
/// The modal is presented above the tab bar, so it never conflicts with the
/// tabs' stacks: they stay exactly as they were and are visible again after
/// the modal is dismissed.
///
/// ```swift
/// struct EditProfileModal: ModalDestination {
///     typealias Route = Never                   // no inner screens
///     let style: ModalStyle = .fullScreen
///
///     func makeRoot(context: NavigationContext) -> some View {
///         EditProfileScreen(onClose: context.app.dismiss)
///     }
/// }
///
/// appRouter.present(EditProfileModal())
/// ```
public protocol ModalDestination: NavigationFlow {
    /// The presentation style. Defaults to `.sheet`.
    var style: ModalStyle { get }

    /// Sheet-only options. Ignored for `.fullScreen`. Defaults to `SheetConfiguration()`.
    var sheet: SheetConfiguration { get }
}

extension ModalDestination {
    public var style: ModalStyle { .sheet }
    public var sheet: SheetConfiguration { SheetConfiguration() }
}

/// Options for a modal presented as `.sheet`. Data only: the container applies them.
///
/// `nonisolated`: plain data, usable from any actor (the module defaults to `MainActor`).
public nonisolated struct SheetConfiguration {
    /// The grabber at the top of the sheet.
    ///
    /// Defaults to `.visible`. The system default (`.automatic`) hides it when
    /// the sheet has a single detent, which is why it may seem to be missing.
    public var dragIndicator: Visibility

    /// The heights the sheet can snap to. Defaults to full height.
    ///
    /// Several detents (for example `[.medium, .large]`) let the user resize the sheet.
    public var detents: Set<PresentationDetent>

    public init(dragIndicator: Visibility = .visible, detents: Set<PresentationDetent> = [.large]) {
        self.dragIndicator = dragIndicator
        self.detents = detents
    }
}

/// A modal that is currently on screen, together with its own stack.
///
/// Created only by `AppRouter.present(_:)`; apps read it through
/// `AppRouter.modal`. The fresh `id` makes SwiftUI treat each
/// presentation as new, and the fresh `StackRouter` starts every modal at its root.
@MainActor
public struct PresentedModal: Identifiable {
    /// A new identifier for every presentation.
    public let id = UUID()
    /// The modal being shown.
    public let destination: any ModalDestination
    /// The modal's own navigation stack. Starts empty, at the modal's root.
    public let stack = StackRouter()

    init(destination: any ModalDestination) {
        self.destination = destination
    }
}
