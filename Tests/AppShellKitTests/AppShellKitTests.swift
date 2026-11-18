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

private struct InvalidLink: Error {}

/// Owns every link and rejects it (test double).
private struct RejectingHandler: DeepLinkHandler {
    func command(for url: URL) throws -> (any NavigationCommand)? {
        throw InvalidLink()
    }
}

/// `myapp://tab/<id>`: selects the tab named in the link — an id from outside.
private struct TabLinks: DeepLinkHandler {
    func command(for url: URL) -> (any NavigationCommand)? {
        guard url.host() == "tab", let id = url.pathComponents.last else { return nil }
        return SelectTab(id: id)
    }
}

private struct SelectTab: NavigationCommand {
    let id: String
    func execute(on router: AppRouter) { router.select(id) }
}

/// Changes everything a command can change, then fails.
private struct BrokenCommand: NavigationCommand {
    func execute(on router: AppRouter) throws {
        router.select("home")
        router.stack(for: "home").push(TestRoute.detail(7))
        router.present(TestModal())
        throw InvalidLink()
    }
}

private struct PushOntoUnknownTab: NavigationCommand {
    func execute(on router: AppRouter) { router.stack(for: "nope").push(TestRoute.detail(1)) }
}

/// Selects Home, then runs a failing command and ignores its result.
private struct OuterCommand: NavigationCommand {
    func execute(on router: AppRouter) {
        router.select("home")
        router.perform(PushThenUnknownTab())
    }
}

/// Pushes, then names a tab that doesn't exist.
private struct PushThenUnknownTab: NavigationCommand {
    func execute(on router: AppRouter) {
        router.stack(for: "home").push(TestRoute.detail(1))
        router.stack(for: "nope").push(TestRoute.detail(2))
    }
}

extension DeepLinkResult {
    var isHandled: Bool { if case .handled = self { true } else { false } }
    var isUnhandled: Bool { if case .unhandled = self { true } else { false } }
    var failure: (any Error)? { if case .failed(let error) = self { error } else { nil } }
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
        #expect(router.open(URL(string: "myapp://x")!).isHandled)
        #expect(router.stack(for: "home").path == NavigationPath([TestRoute.detail(1)]))
    }

    @Test func unknownLinkIsIgnored() {
        let router = AppRouter(tabIDs: ["home"], deepLinkHandlers: [
            FixedHandler(host: "x", command: OpenDetail(number: 1)),
        ])
        #expect(router.open(URL(string: "myapp://other")!).isUnhandled)
        #expect(router.stack(for: "home").path.isEmpty)
    }

    @Test func noHandlersMeansNothingIsHandled() {
        #expect(AppRouter(tabIDs: ["home"]).open(URL(string: "myapp://x")!).isUnhandled)
    }

    @Test func invalidLinkIsReportedAndLaterHandlersAreNotAsked() {
        let router = AppRouter(tabIDs: ["home"], deepLinkHandlers: [
            RejectingHandler(),
            FixedHandler(host: "x", command: OpenDetail(number: 1)),
        ])
        #expect(router.open(URL(string: "myapp://x")!).failure is InvalidLink)
        #expect(router.stack(for: "home").path.isEmpty)
    }

    @Test func linkToUnknownTabFailsWithoutCrashing() {
        let router = AppRouter(tabIDs: ["home", "profile"], deepLinkHandlers: [TabLinks()])
        let failure = router.open(URL(string: "myapp://tab/settings")!).failure
        #expect(failure as? UnknownTabError == UnknownTabError(tabID: "settings"))
        #expect(router.selectedTab == "home")
        #expect(router.open(URL(string: "myapp://tab/profile")!).isHandled)
        #expect(router.selectedTab == "profile")
    }
}

// MARK: - Commands

@Suite("Command safety")
struct CommandSafetyTests {
    @Test func successfulCommandReturnsSuccess() {
        let router = AppRouter(tabIDs: ["home"])
        #expect((try? router.perform(OpenDetail(number: 1)).get()) != nil)
    }

    @Test func throwingCommandIsRolledBack() {
        let router = AppRouter(tabIDs: ["profile", "home"])
        router.stack(for: "home").push(TestRoute.detail(3))
        let result = router.perform(BrokenCommand())
        #expect(throws: InvalidLink.self) { try result.get() }
        #expect(router.selectedTab == "profile")
        #expect(router.stack(for: "home").path == NavigationPath([TestRoute.detail(3)]))
        #expect(router.modal == nil)
    }

    @Test func unknownTabFailsTheWholeCommand() {
        let router = AppRouter(tabIDs: ["home"])
        let result = router.perform(PushThenUnknownTab())
        #expect(throws: UnknownTabError(tabID: "nope")) { try result.get() }
        #expect(router.stack(for: "home").path.isEmpty)
    }

    @Test func pushOntoUnknownTabDoesNotCrashOrLeak() {
        let router = AppRouter(tabIDs: ["home"])
        let result = router.perform(PushOntoUnknownTab())
        #expect(throws: UnknownTabError(tabID: "nope")) { try result.get() }
        #expect(router.stack(for: "home").path.isEmpty)
    }

    @Test func nestedFailureIsRolledBackOnItsOwn() {
        let router = AppRouter(tabIDs: ["profile", "home"])
        let result = router.perform(OuterCommand())
        #expect((try? result.get()) != nil)
        #expect(router.selectedTab == "home")                       // outer change kept
        #expect(router.stack(for: "home").path.isEmpty)              // inner change rolled back
    }

    @Test func rolledBackModalKeepsItsStack() {
        let router = AppRouter(tabIDs: ["home"])
        router.present(TestModal())
        router.modal?.stack.push(TestRoute.detail(5))
        let shown = router.modal?.id
        router.perform(BrokenCommand())
        #expect(router.modal?.id == shown)
        #expect(router.modal?.stack.path == NavigationPath([TestRoute.detail(5)]))
    }
}
