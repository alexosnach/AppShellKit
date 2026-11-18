# AppShellKit

The skeleton of a SwiftUI app: a tab bar where every tab has its own navigation stack, a modal layer above it, routers you can drive from code, navigation commands and deep links. Your features plug into it; the library knows none of them.

## Requirements

- Swift 6.2+ (Xcode 26+)
- iOS 26+

## Installation

In Xcode: **File → Add Package Dependencies…**, paste `https://github.com/alexosnach/AppShellKit.git`.

Or in `Package.swift`:

```swift
.package(url: "https://github.com/alexosnach/AppShellKit.git", from: "0.1.2")
```

AppShellKit is pre-1.0: the API may change between minor versions.

## What you get

- **Tabs with their own stacks.** Each tab gets a `NavigationStack` and a `StackRouter`. Navigation stacks are preserved across tab switches, rotation, and folding or unfolding (tested in the iPhone Duo simulator).
- **One tab, no tab bar.** With a single tab, the bar is not shown.
- **A modal layer** (`sheet` / `fullScreenCover`) above the tab bar, with its own stack, presentable from anywhere.
- **Navigation as data.** `AppRouter` and `StackRouter` hold the state, so navigation is testable without UI.
- **Commands** for cross-feature navigation: a feature exposes a command instead of its internals.
- **Deep links** from any source (URL schemes, universal links, push, attribution SDKs) through one entry point.
- **Built for dependency injection.** Factories receive the routers, so view models get everything through `init`.

## Quick start

### 1. Describe a tab

```swift
import AppShellKit
import SwiftUI

nonisolated enum HomeRoute: Hashable {   // plain data: see the note below
    case detail(Int)
}

struct HomeTab: TabDescriptor {
    let id = "home"
    let title = "Home"
    let icon: TabIcon = .system("house")

    let storage: any StorageService          // your own service

    func makeRoot(context: NavigationContext) -> some View {
        // Inject services and routers into the view model through `init`.
        HomeScreen(viewModel: HomeViewModel(storage: storage, router: context.stack))
    }

    func makeScreen(for route: HomeRoute, context: NavigationContext) -> some View {
        switch route {
        case .detail(let id): DetailScreen(id: id)
        }
    }
}
```

A tab without inner screens declares `typealias Route = Never` and skips `makeScreen`.

> **Routes are `nonisolated`.** New Xcode 26 apps isolate code to the main actor by default. In such an app a plain `enum HomeRoute: Hashable` gets a main-actor `Hashable` conformance, and the tab fails to compile with *"conformance … crosses into main actor-isolated code"*. A route is plain data, so mark it `nonisolated`.

### 2. Assemble the app (Composition Root)

`Storage` here is your app's own `@Observable` class that conforms to your `StorageService` protocol.

```swift
@main
struct MyApp: App {
    @State private var storage = Storage()   // created once, shared by every feature

    var body: some Scene {
        WindowGroup {
            RootTabView(
                tabs: [HomeTab(storage: storage), ProfileTab(storage: storage)],
                accentColor: .blue,                 // screens
                tabBarSelectedColor: .orange,       // tab bar only
                deepLinks: [HomeDeepLinks()]
            )
        }
    }
}
```

### 3. Navigate

In the snippets below, `stack` is a `StackRouter` and `appRouter` is the `AppRouter`. In a factory they come from `context.stack` and `context.app`; in a screen, read them from the environment.

Inside a tab or a modal, use its `StackRouter` (from `NavigationContext.stack` or `@Environment(StackRouter.self)`):

```swift
stack.push(HomeRoute.detail(3))
stack.pop()
stack.popToRoot()
```

Across features, perform a command the target feature exposes, through `AppRouter` (from `NavigationContext.app` or `@Environment(AppRouter.self)`):

```swift
struct OpenHomeDetail: NavigationCommand {
    let id: Int
    func execute(on router: AppRouter) {
        router.select("home")
        router.stack(for: "home").push(HomeRoute.detail(id))
    }
}

appRouter.perform(OpenHomeDetail(id: 3))
```

Present a modal from anywhere:

```swift
appRouter.present(EditProfileModal())   // a ModalDestination
appRouter.dismiss()
```

### 4. Deep links

```swift
struct HomeDeepLinks: DeepLinkHandler {
    func command(for url: URL) -> (any NavigationCommand)? {
        // myapp://home/detail/3 — validate everything: links are untrusted input.
        let path = url.pathComponents.filter { $0 != "/" }
        guard url.scheme == "myapp", url.host() == "home",
              path.count == 2, path[0] == "detail",
              let id = Int(path[1]), (1...100).contains(id)
        else { return nil }
        return OpenHomeDetail(id: id)
    }
}
```

URL schemes and universal links arrive automatically. For other sources (push notifications, attribution SDKs), call `appRouter.open(url)`. Unknown links are ignored and return `false`.

## Contracts

- **At least one tab; `id`s are unique and stable.** An empty list or a duplicate `id` traps at launch. `select(_:)` or `stack(for:)` with an unknown `id` traps too: it is a programmer error.
- **`makeRoot` / `makeScreen` may be called many times.** Let screens own their view models with `@State`, and do heavy work in `.task`.
- **Routes are plain `nonisolated` data** (`Hashable`).
- **Don't wrap screens in `NavigationStack`** and don't register `navigationDestination` yourself: the container does both.
- **One modal at a time.** Presenting a new modal replaces the current one.
- **Commands and deep links only navigate.** Never map a link to an action such as a payment.

## Logging

The library writes nothing to the console or the system log. Unknown deep links return `false` from `open(_:)`, so the app decides whether and how to report them.

## Tab bar

The tab bar is the system one: Liquid Glass, VoiceOver, Dynamic Type and adaptive layouts come from Apple. Only the selected item's color can be customized (`tabBarSelectedColor`); the unselected color follows the system.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Issues and contributions

Found a bug or have an idea? Open an issue at https://github.com/alexosnach/AppShellKit/issues. Pull requests are welcome.

## License

MIT. See [LICENSE](LICENSE).
