//
//  TabDescriptor.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// Describes one tab of the app — the skeleton's main extension point.
///
/// Answers **"what am I"**: identifier, title, icon and badge. The screens
/// (root and routes) come from `NavigationFlow`. It knows nothing about **how**
/// it will be shown — by the system tab bar or a custom one — so there is no
/// `tabItem`, color or other rendering here.
///
/// An app adds a tab by creating a new type and passing it to `RootTabView`.
/// The library itself does not change (Open/Closed).
///
/// ```swift
/// enum SettingsRoute: Hashable { case about }
///
/// struct SettingsTab: TabDescriptor {
///     let id = "settings"
///     let title = "Settings"
///     let icon: TabIcon = .system("gear")
///
///     let storage: any StorageService       // your own service, injected by the app
///
///     func makeRoot(context: NavigationContext) -> some View {
///         SettingsScreen(viewModel: SettingsViewModel(storage: storage,
///                                                     router: context.stack))
///     }
///
///     func makeScreen(for route: SettingsRoute, context: NavigationContext) -> some View {
///         switch route {
///         case .about: AboutScreen()
///         }
///     }
/// }
/// ```
public protocol TabDescriptor: NavigationFlow {
    /// A unique, stable tab identifier.
    ///
    /// Independent of tab order. `AppRouter` uses it to select the tab and find
    /// its stack. Two tabs with the same `id` are a programmer error: the app
    /// traps at launch.
    var id: String { get }

    /// The title shown under the icon in the tab bar.
    var title: String { get }

    /// The tab icon.
    var icon: TabIcon { get }

    /// The badge count. `0` hides the badge.
    var badge: Int { get }

    /// The VoiceOver label. Defaults to `title`.
    var accessibilityLabel: String { get }
}

/// Defaults, so tabs don't repeat the same values (DRY).
extension TabDescriptor {
    public var badge: Int { 0 }
    public var accessibilityLabel: String { title }
}
