//
//  PerformanceTests.swift
//  AppShellKit
//

import Foundation
import SwiftUI
import XCTest
@testable import AppShellKit

// Cost of the library's own operations, without any UI. Run in Release to get
// meaningful numbers (see README, "Performance"). The Android port runs the same
// scenarios with Jetpack Microbenchmark, so the two can be compared.

private nonisolated enum PerfRoute: Hashable { case detail(Int) }

private struct PerfModal: ModalDestination {
    typealias Route = Never
    func makeRoot(context: NavigationContext) -> some View { EmptyView() }
}

private struct PerfCommand: NavigationCommand {
    let number: Int
    func execute(on router: AppRouter) {
        router.select("home")
        router.stack(for: "home").push(PerfRoute.detail(number))
    }
}

private struct PerfLinks: DeepLinkHandler {
    func command(for url: URL) -> (any NavigationCommand)? {
        guard url.host() == "home", let number = Int(url.lastPathComponent) else { return nil }
        return PerfCommand(number: number)
    }
}

private struct FailingCommand: NavigationCommand {
    func execute(on router: AppRouter) {
        router.stack(for: "home").push(PerfRoute.detail(1))
        router.select("nope")
    }
}

/// `nonisolated` class (XCTestCase's initializers are), main-actor tests.
nonisolated final class PerformanceTests: XCTestCase {
    /// Iterations per measured block; the same counts are used on Android.
    private nonisolated let count = 1_000

    private nonisolated var options: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        return options
    }

    @MainActor func testPushAndPop() {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            let stack = StackRouter()
            for index in 0..<count { stack.push(PerfRoute.detail(index)) }
            for _ in 0..<count { stack.pop() }
        }
    }

    @MainActor func testPerformCommand() {
        let router = AppRouter(tabIDs: ["home", "profile"])
        measure(metrics: [XCTClockMetric()], options: options) {
            for index in 0..<count { router.perform(PerfCommand(number: index)) }
            router.stack(for: "home").popToRoot()
        }
    }

    @MainActor func testFailedCommandRollback() {
        let router = AppRouter(tabIDs: ["home", "profile"])
        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<count { router.perform(FailingCommand()) }
        }
    }

    @MainActor func testOpenDeepLink() {
        let router = AppRouter(tabIDs: ["home", "profile"], deepLinkHandlers: [PerfLinks()])
        let url = URL(string: "myapp://home/detail/7")!
        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<count { router.open(url) }
            router.stack(for: "home").popToRoot()
        }
    }

    @MainActor func testPresentAndDismiss() {
        let router = AppRouter(tabIDs: ["home"])
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            for _ in 0..<count {
                router.present(PerfModal())
                router.dismiss()
            }
        }
    }
}
