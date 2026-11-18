//
//  AppShellKitTests.swift
//  AppShellKit
//

import Foundation
import SwiftUI
import Testing
@testable import AppShellKit

// The navigation state is plain data in routers, so it is tested without
// rendering a single view.

// MARK: - Fixtures

private enum TestRoute: Hashable { case detail(Int) }

/// A command that pushes a detail screen in the "home" tab.
private struct OpenDetail: NavigationCommand {
    let number: Int
    func execute(on router: AppRouter) {
        router.select("home")
        router.stack(for: "home").push(TestRoute.detail(number))
    }
}

private struct TestModal: ModalDestination {
    typealias Route = Never
    var style: ModalStyle = .sheet
    func makeRoot(context: NavigationContext) -> some View { EmptyView() }
}

/// Answers links whose host matches, with a fixed command (test double).
private struct FixedHandler: DeepLinkHandler {
    let host: String
    let command: any NavigationCommand
    func command(for url: URL) -> (any NavigationCommand)? {
        url.host() == host ? command : nil
    }
}

// MARK: - StackRouter

@Suite("StackRouter")
struct StackRouterTests {
    @Test func startsAtRoot() {
        #expect(StackRouter().path.isEmpty)
    }

    @Test func pushAddsRoutesInOrder() {
        let router = StackRouter()
        router.push(TestRoute.detail(1))
        router.push(TestRoute.detail(2))
        #expect(router.path == NavigationPath([TestRoute.detail(1), TestRoute.detail(2)]))
    }

    @Test func popRemovesTopRoute() {
        let router = StackRouter()
        router.push(TestRoute.detail(1))
        router.push(TestRoute.detail(2))
        router.pop()
        #expect(router.path == NavigationPath([TestRoute.detail(1)]))
    }

    @Test func popAtRootDoesNothing() {
        let router = StackRouter()
        router.pop()
        #expect(router.path.isEmpty)
    }

    @Test func popToRootClearsStack() {
        let router = StackRouter()
        router.push(TestRoute.detail(1))
        router.popToRoot()
        #expect(router.path.isEmpty)
    }
}

// MARK: - AppRouter

@Suite("AppRouter")
struct AppRouterTests {
    @Test func selectsFirstTabAtLaunch() {
        #expect(AppRouter(tabIDs: ["home", "profile"]).selectedTab == "home")
    }

    @Test func selectChangesTab() {
        let router = AppRouter(tabIDs: ["home", "profile"])
        router.select("profile")
        #expect(router.selectedTab == "profile")
    }

    @Test func eachTabHasItsOwnStack() {
        let router = AppRouter(tabIDs: ["home", "profile"])
        router.stack(for: "home").push(TestRoute.detail(3))
        #expect(router.stack(for: "home").path.count == 1)
        #expect(router.stack(for: "profile").path.isEmpty)
    }

    @Test func stackIsStableAcrossLookups() {
        let router = AppRouter(tabIDs: ["home"])
        #expect(router.stack(for: "home") === router.stack(for: "home"))
    }

    @Test func performRunsCommand() {
        let router = AppRouter(tabIDs: ["profile", "home"])
        router.perform(OpenDetail(number: 3))
        #expect(router.selectedTab == "home")
        #expect(router.stack(for: "home").path == NavigationPath([TestRoute.detail(3)]))
    }
}

// MARK: - Modals

@Suite("Modal layer")
struct ModalTests {
    @Test func noModalAtLaunch() {
        #expect(AppRouter(tabIDs: ["home"]).modal == nil)
    }

    @Test func presentAndDismiss() {
        let router = AppRouter(tabIDs: ["home"])
        router.present(TestModal(style: .fullScreen))
        #expect(router.modal?.destination.style == .fullScreen)
        router.dismiss()
        #expect(router.modal == nil)
    }

    @Test func presentingReplacesCurrentModal() {
        let router = AppRouter(tabIDs: ["home"])
        router.present(TestModal())
        let first = router.modal?.id
        router.present(TestModal())
        #expect(router.modal?.id != first)
    }

    @Test func everyModalStartsAtItsRoot() {
        let router = AppRouter(tabIDs: ["home"])
        router.present(TestModal())
        router.modal?.stack.push(TestRoute.detail(1))
        router.present(TestModal())
        #expect(router.modal?.stack.path.isEmpty == true)
    }

    @Test func modalDoesNotTouchTabStacks() {
        let router = AppRouter(tabIDs: ["home"])
        router.stack(for: "home").push(TestRoute.detail(3))
        router.present(TestModal())
        router.modal?.stack.push(TestRoute.detail(9))
        router.dismiss()
        #expect(router.stack(for: "home").path == NavigationPath([TestRoute.detail(3)]))
    }

    @Test func presentModalCommandPresents() {
        let router = AppRouter(tabIDs: ["home"])
        router.perform(PresentModal(destination: TestModal(style: .fullScreen)))
        #expect(router.modal?.destination.style == .fullScreen)
    }

    @Test func modalDefaults() {
        #expect(TestModal().sheet.dragIndicator == .visible)
        #expect(TestModal().sheet.detents == [.large])
    }
}

// MARK: - Deep links

@Suite("Deep links")
struct DeepLinkTests {
    @Test func firstMatchingHandlerWins() {
        let router = AppRouter(tabIDs: ["home"], deepLinkHandlers: [
            FixedHandler(host: "x", command: OpenDetail(number: 1)),
            FixedHandler(host: "x", command: OpenDetail(number: 2)),
        ])
        #expect(router.open(URL(string: "myapp://x")!))
        #expect(router.stack(for: "home").path == NavigationPath([TestRoute.detail(1)]))
    }

    @Test func unknownLinkIsIgnored() {
        let router = AppRouter(tabIDs: ["home"], deepLinkHandlers: [
            FixedHandler(host: "x", command: OpenDetail(number: 1)),
        ])
        #expect(!router.open(URL(string: "myapp://other")!))
        #expect(router.stack(for: "home").path.isEmpty)
    }

    @Test func noHandlersMeansNothingIsHandled() {
        #expect(!AppRouter(tabIDs: ["home"]).open(URL(string: "myapp://x")!))
    }
}
