# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.2]: https://github.com/alexosnach/AppShellKit/compare/0.1.1...0.1.2
[0.1.1]: https://github.com/alexosnach/AppShellKit/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/alexosnach/AppShellKit/releases/tag/0.1.0
