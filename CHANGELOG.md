# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-10-08

### Added
- Dependabot GitHub workflow for automated dependency updates (#295)
- Changelog and release automation system (#291)
- Container separation for local development environments (#294)

### Changed
- Updated Trading Card API SDK from dev-main to stable v0.1.9 (#300)
- Converted all frontend API calls to use V1 routes (#292)
- Updated README documentation (#290)
- Updated all dependencies including security fixes (#301)

### Fixed
- SSL/TLS handshake noise in application logs (#299)

### Security
- Updated axios from ^1.8 to ^1.12.0 (security fix)
- Updated postcss from 8.4.31 to 8.4.47 (security fix)
- Resolved 12 npm security vulnerabilities including 3 critical and 1 high severity

[Unreleased]: https://github.com/cardtechie/cardalmanac-app/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/cardtechie/cardalmanac-app/releases/tag/v0.2.0
