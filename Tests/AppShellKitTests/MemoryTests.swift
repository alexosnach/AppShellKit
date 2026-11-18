//
//  MemoryTests.swift
//  AppShellKit
//

import Foundation
import SwiftUI
import Testing
@testable import AppShellKit

// No retain cycles: everything the library creates is freed when the app lets go.

/// Tells when it is freed.
private final class Tracker {
    nonisolated(unsafe) static var freed = 0
    deinit { Tracker.freed += 1 }
}

/// A modal that holds a service, like a real one.
private struct TrackedModal: ModalDestination {
    typealias Route = Never
    let service = Tracker()
    func makeRoot(context: NavigationContext) -> some View { EmptyView() }
}

/// A handler and a command that hold services too.
private struct TrackedHandler: DeepLinkHandler {
    let service = Tracker()
    func command(for url: URL) -> (any NavigationCommand)? { TrackedCommand() }
}

private struct TrackedCommand: NavigationCommand {
    let service = Tracker()
    func execute(on router: AppRouter) { router.present(TrackedModal()) }
}

@Suite("Memory", .serialized)
struct MemoryTests {
    @Test func dismissedModalIsFreed() {
        Tracker.freed = 0
        let router = AppRouter(tabIDs: ["home"])
        router.present(TrackedModal())
        weak var stack = router.modal?.stack
        router.dismiss()
        #expect(Tracker.freed == 1)
        #expect(stack == nil)
    }

    @Test func replacedModalIsFreed() {
        Tracker.freed = 0
        let router = AppRouter(tabIDs: ["home"])
        router.present(TrackedModal())
        router.present(TrackedModal())
        #expect(Tracker.freed == 1)
    }

    @Test func routerAndEverythingItHoldsAreFreed() {
        Tracker.freed = 0
        weak var weakRouter: AppRouter?
        weak var weakStack: StackRouter?
        do {
            let router = AppRouter(tabIDs: ["home", "profile"], deepLinkHandlers: [TrackedHandler()])
            router.stack(for: "home").push(1)
            router.open(URL(string: "myapp://x")!)   // command + modal, both tracked
            weakRouter = router
            weakStack = router.stack(for: "home")
        }
        #expect(weakRouter == nil)
        #expect(weakStack == nil)
        // handler + command + modal
        #expect(Tracker.freed == 3)
    }

    @Test func rolledBackModalIsFreed() {
        Tracker.freed = 0
        struct PresentThenFail: NavigationCommand {
            func execute(on router: AppRouter) throws {
                router.present(TrackedModal())
                throw CancellationError()
            }
        }
        let router = AppRouter(tabIDs: ["home"])
        router.perform(PresentThenFail())
        #expect(router.modal == nil)
        #expect(Tracker.freed == 1)
    }
}
