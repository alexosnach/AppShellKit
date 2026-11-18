# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-11-18

Deep links and commands never crash the app.

### Changed (breaking)
- `AppRouter.open(_:)` returns `DeepLinkResult` (`.handled`, `.unhandled`, `.failed(error)`) instead of `Bool`.
- `DeepLinkHandler.command(for:)` can throw to reject a link it owns but that is invalid. Existing non-throwing handlers still compile.
- `NavigationCommand.execute(on:)` can throw. Existing non-throwing commands still compile.

### Added
- `AppRouter.perform(_:)` returns `Result<Void, any Error>` and runs a command as a whole or not at all: if it throws or names an unknown tab, all its changes are rolled back.
- `UnknownTabError`: an unknown tab id inside a command fails that command instead of trapping.
- `RootTabView(onDeepLink:)`: reports every URL scheme or universal link and its result.
- Performance tests (XCTest `measure`) and memory tests (no retain cycles).

### Fixed
- iOS 26.0: freeing a `StackRouter` or `AppRouter` outside a Swift task (for example in an XCTest method) could corrupt the heap and crash, through the isolated-deinit path of the Swift runtime. Both now have a `nonisolated deinit`.

## [0.1.2] - 2026-11-18

### Changed
- Documentation pass: corrected and completed doc comments (routes and screens, `AppRouter` init preconditions, full-screen modals, `PresentModal`, `PresentedModal`).
- README: pre-1.0 notice, clearer quick start, precise tab bar color note, issues section, link to this changelog.

## [0.1.1]

### Fixed
- Stale documentation.

### Changed
- Documented `nonisolated` routes for apps with main-actor default isolation.
- Removed all logging: the library writes nothing to the console or the system log.
- `select(_:)` traps on an unknown tab id.

## [0.1.0]

### Added
- Initial release: tab bar with a navigation stack per tab, a modal layer, routers, navigation commands and deep links.

[0.2.0]: https://github.com/alexosnach/AppShellKit/compare/0.1.2...0.2.0
[0.1.2]: https://github.com/alexosnach/AppShellKit/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/alexosnach/AppShellKit/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/alexosnach/AppShellKit/releases/tag/0.1.0
