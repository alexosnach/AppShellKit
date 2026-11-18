//
//  RootTabView.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// The app's root container: the system tab bar where every tab has its own stack.
///
/// What the container guarantees (the same in every app):
/// - every tab has its own `NavigationStack` and its own `StackRouter`;
/// - a tab's stack is preserved when switching tabs;
/// - with a single tab, no tab bar is shown — just that tab's stack;
/// - every screen's environment contains its tab's `StackRouter` and the shared `AppRouter`.
///
/// What the app decides: the list of tabs and the colors. All of it is injected
/// from outside (DI); the container knows no concrete tab.
///
/// Colors are configured independently:
/// - `accentColor` — the app-wide accent, inherited by every screen;
/// - `tabBarSelectedColor` — the selected tab color, tab bar only.
///   When not set, the tab bar uses `accentColor` too.
///
/// The tab bar is the system one: Liquid Glass, VoiceOver, Dynamic Type and
/// adaptive layouts (such as the side bar on iPhone Duo) come from Apple.
/// There is deliberately no unselected color: the Liquid Glass tab bar
/// (verified on iOS 27.2) ignores every public API for it.
///
/// ```swift
/// RootTabView(
///     tabs: [HomeTab(), ProfileTab()],
///     accentColor: .blue,              // screens
///     tabBarSelectedColor: .orange     // tab bar only
/// )
/// ```
public struct RootTabView: View {
    /// Tabs in display order.
    let tabs: [any TabDescriptor]

    /// The app accent color for the content of every tab.
    let accentColor: Color

    /// The selected tab color. `nil` means `accentColor`.
    let tabBarSelectedColor: Color?

    /// App-wide navigation. Created once for the container's lifetime.
    @State private var router: AppRouter

    /// - Parameters:
    ///   - tabs: Tabs in display order. Their `id`s must be unique.
    ///   - accentColor: The app accent. Defaults to `AccentColor` from the asset catalog.
    ///   - tabBarSelectedColor: The selected tab color, tab bar only. Defaults to `accentColor`.
    ///   - deepLinks: Deep link handlers, asked in order. Defaults to none.
    public init(
        tabs: [any TabDescriptor],
        accentColor: Color = .accentColor,
        tabBarSelectedColor: Color? = nil,
        deepLinks: [any DeepLinkHandler] = []
    ) {
        precondition(!tabs.isEmpty, "RootTabView needs at least one tab")
        self.tabs = tabs
        self.accentColor = accentColor
        self.tabBarSelectedColor = tabBarSelectedColor
        _router = State(initialValue: AppRouter(tabIDs: tabs.map(\.id), deepLinkHandlers: deepLinks))
    }

    public var body: some View {
        Group {
            if let single = tabs.first, tabs.count == 1 {
                // A tab bar with one item switches nothing, so it is not shown.
                stackContent(for: single)
            } else {
                tabBar
            }
        }
        // Modals hang above the tab bar, so they never conflict with tab stacks.
        .sheet(item: modalBinding(for: .sheet), content: modalContent)
        .fullScreenCover(item: modalBinding(for: .fullScreen), content: modalContent)
        // URL schemes and universal links. Other sources call `AppRouter.open(_:)`.
        .onOpenURL { url in router.open(url) }
        .environment(router)
    }

    /// The system tab bar with one stack per tab.
    private var tabBar: some View {
        TabView(selection: Bindable(router).selectedTab) {
            ForEach(tabs, id: \.id) { tab in
                Tab(value: tab.id) {
                    stackContent(for: tab)
                } label: {
                    Label {
                        Text(tab.title)
                    } icon: {
                        tab.icon.systemImage
                    }
                    .accessibilityLabel(tab.accessibilityLabel)
                }
                .badge(tab.badge)
            }
        }
        .tint(tabBarSelectedColor ?? accentColor)
    }

    /// One tab's navigation stack. Shared by both layouts, so a single tab
    /// behaves exactly like a tab inside the tab bar.
    private func stackContent(for tab: any TabDescriptor) -> some View {
        stackContent(for: tab, stack: router.stack(for: tab.id))
    }

    /// A modal's navigation stack. Same builder as tabs, so screens work
    /// identically inside a tab and inside a modal.
    private func modalContent(_ modal: PresentedModal) -> some View {
        stackContent(for: modal.destination, stack: modal.stack)
            // Sheet-only modifiers; a full-screen cover ignores them.
            .presentationDragIndicator(modal.destination.sheet.dragIndicator)
            .presentationDetents(modal.destination.sheet.detents)
            // Sheets don't reliably inherit the presenter's environment.
            .environment(router)
    }

    /// Builds a navigation stack for any flow — tab or modal (DRY).
    private func stackContent(for flow: any NavigationFlow, stack: StackRouter) -> some View {
        NavigationStack(path: Bindable(stack).path) {
            // Root plus registered routes; erased to AnyView once per stack.
            // The factory gets the routers so it can inject them into view models.
            flow.makeStackContent(context: NavigationContext(stack: stack, app: router))
        }
        .environment(stack)
        // The tab bar's `.tint` would be inherited by content. Give screens the
        // app accent so the tab bar color doesn't leak into features.
        .tint(accentColor)
    }

    /// A binding that is non-`nil` only while a modal of the given style is shown.
    ///
    /// Splits the single `AppRouter.modal` into the two SwiftUI presenters.
    /// Setting it to `nil` (system swipe-down) dismisses through the router,
    /// so the router stays the single source of truth.
    ///
    /// The `id` check stops a closing old modal from dismissing a new one that
    /// has just replaced it.
    private func modalBinding(for style: ModalStyle) -> Binding<PresentedModal?> {
        let shownID = router.modal?.id
        return Binding(
            get: { router.modal?.destination.style == style ? router.modal : nil },
            set: { newValue in
                if newValue == nil, router.modal?.id == shownID { router.dismiss() }
            }
        )
    }
}
