# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

-   Land the stranded main-to-develop back-merge workflow on `main` and add a scheduled branch-drift guard (#405)
    -   Merging fires the back-merge workflow, which opens a "Sync main into develop" PR needing one manual `CHANGELOG.md` resolution — take `main`'s side in full.

## [0.2.7] - 2025-10-10

### Changed

-   Improve release notes to use CHANGELOG.md content (#349, #350)
    -   Release notes now automatically extract from CHANGELOG.md
    -   Falls back to git commit analysis if version not in CHANGELOG
    -   Maintains single source of truth for release information

## [0.2.6] - 2025-10-09

### Changed

-   Configure Dependabot to only create PRs for security updates (#336, #348)

## [0.2.5] - 2025-10-09

### Changed

-   Updated all dependencies to latest versions (#335, #343)
    -   GitHub Actions: checkout v5, login-action v3, build-push-action v6
    -   NPM: prettier 3.6.2, bootstrap 5.3.8, sass 1.93.2, vue 3.5.22, and more
    -   Composer: guzzlehttp 7.10.0, laravel 12.33.0, phpunit 11.5.42, symfony 7.3.4
    -   54 transitive composer dependency updates

### Fixed

-   Mix manifest error in blog build configuration (#343)
-   Tailwind CSS v3 compatibility (deferred v4 upgrade to #344)
-   tw-elements v2.0.0 plugin path

## [0.2.4] - 2025-10-08

### Fixed

-   Docker tagging invalid reference format (#342)

## [0.2.3] - 2025-10-08

### Added

-   GitHub Actions build status documentation

### Fixed

-   GitHub Actions build failure: Removed Claude API key dependency (#340)

## [0.2.2] - 2025-10-07

### Fixed

-   GitHub Actions workflow tag format (#338)
-   Removed v prefix from release tags to match project convention

## [0.2.1] - 2025-10-07

### Fixed

-   Version script tagging logic to work with project's tagging convention (#334)
-   Hotfix branch version detection

## [0.2.0] - 2025-10-08

### Added

-   Dependabot GitHub workflow for automated dependency updates (#295)
-   Changelog and release automation system (#291)
-   Container separation for local development environments (#294)

### Changed

-   Updated Trading Card API SDK from dev-main to stable v0.1.9 (#300)
-   Converted all frontend API calls to use V1 routes (#292)
-   Updated README documentation (#290)
-   Updated all dependencies including security fixes (#301)

### Fixed

-   SSL/TLS handshake noise in application logs (#299)

### Security

-   Updated axios from ^1.8 to ^1.12.0 (security fix)
-   Updated postcss from 8.4.31 to 8.4.47 (security fix)
-   Resolved 12 npm security vulnerabilities including 3 critical and 1 high severity

[Unreleased]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.7...HEAD
[0.2.7]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.6...0.2.7
[0.2.6]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.5...0.2.6
[0.2.5]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.4...0.2.5
[0.2.4]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.3...0.2.4
[0.2.3]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.2...0.2.3
[0.2.2]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.1...0.2.2
[0.2.1]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/cardtechie/cardalmanac-app/releases/tag/0.2.0
