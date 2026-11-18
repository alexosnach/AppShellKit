//
//  TabIcon.swift
//  AppShellKit
//
//  Created by alex on 18/11/2026.
//

import SwiftUI

/// A tab icon.
///
/// This is **data**: the type says *which* icon is needed. How to draw it is up
/// to the container (`RootTabView`).
///
/// `nonisolated`: plain data, usable from any actor (the module defaults to `MainActor`).
public nonisolated enum TabIcon {
    /// An SF Symbols icon, for example `"house"`.
    case system(String)
    /// An image from the app's asset catalog.
    case asset(String)
}

extension TabIcon {
    /// The icon as an image, for tab bars that show images.
    var systemImage: Image {
        switch self {
        case .system(let name): Image(systemName: name)
        case .asset(let name): Image(name)
        }
    }
}
