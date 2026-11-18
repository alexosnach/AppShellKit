# AppShellKit

The skeleton of a SwiftUI app: a tab bar where every tab has its own navigation stack, a modal layer above it, routers you can drive from code, navigation commands and deep links. Your features plug into it; the library knows none of them.

## Requirements

- Swift 6.2+ (Xcode 26+)
- iOS 26+

## Installation

In Xcode: **File → Add Package Dependencies…**, paste `https://github.com/alexosnach/AppShellKit.git`.

Or in `Package.swift`:

```swift
.package(url: "https://github.com/alexosnach/AppShellKit.git", from: "0.1.0")
```

## What you get

- **Tabs with their own stacks.** Each tab gets a `NavigationStack` and a `StackRouter`. Stacks survive tab switches, folding and rotation (verified on iPhone Duo).
- **One tab, no tab bar.** With a single tab, the bar is not shown.
- **A modal layer** (`sheet` / `fullScreenCover`) above the tab bar, with its own stack, presentable from anywhere.
- **Navigation as data.** `AppRouter` and `StackRouter` hold the state, so navigation is testable without UI.
- **Commands** for cross-feature navigation: a feature exposes a command instead of its internals.
- **Deep links** from any source (URL schemes, universal links, push, attribution SDKs) through one entry point.
- **Dependency injection friendly.** Factories receive the routers, so view models get everything through `init`.

## Quick start

### 1. Describe a tab

```swift
import AppShellKit
import SwiftUI

enum HomeRoute: Hashable {
    case detail(Int)
}

struct HomeTab: TabDescriptor {
    let id = "home"
    let title = "Home"
    let icon: TabIcon = .system("house")

    let storage: any StorageService          // your own service

    func makeRoot(context: NavigationContext) -> some View {
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

### 2. Assemble the app (Composition Root)

```swift
@main
struct MyApp: App {
    @State private var storage = Storage()   // created once

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

Inside a tab, push routes on its stack:

```swift
router.push(HomeRoute.detail(3))
router.pop()
router.popToRoot()
```

Across features, perform a command the target feature exposes:

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
        guard url.host() == "home",
              let id = Int(url.lastPathComponent), (1...100).contains(id)
        else { return nil }
        return OpenHomeDetail(id: id)
    }
}
```

URL schemes and universal links arrive automatically. For other sources, call `appRouter.open(url)`.

## Contracts

- **Tab `id`s are unique and stable.** A duplicate traps at launch.
- **`makeRoot` / `makeScreen` may be called many times.** Let screens own their view models with `@State`, and do heavy work in `.task`.
- **Don't wrap screens in `NavigationStack`** and don't register `navigationDestination` yourself: the container does both.
- **One modal at a time.** Presenting a new modal replaces the current one.
- **Commands and deep links only navigate.** Never map a link to an action such as a payment.

## Tab bar

The tab bar is the system one: Liquid Glass, VoiceOver, Dynamic Type and adaptive layouts come from Apple. Only the selected color can be changed; the Liquid Glass tab bar ignores every public API for the unselected color.

## License

MIT. See [LICENSE](LICENSE).
