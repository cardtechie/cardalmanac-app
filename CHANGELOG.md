# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **[Issue #548]** Run local MySQL on 8.4 to match production.
    - Existing local 8.0 volumes must be converted or recreated; see docs/LOCAL-ENVIRONMENTS.md.

## [0.2.37] - 2026-10-25

### Added

- **[Issue #406]** Add the assign-sprint workflow so newly opened issues are assigned the current Sprint on the project board.
- **[Issue #437]** Add `browse:capture-counts` and a draft-gate surface guard so the API's draft-status gate can be verified against real browse counts.
    - The before/after comparison stays open until `STATUS_GATE_ON_CARDABLE_ENABLED` is enabled in an environment this app can query.
- **[Issue #526]** Add a Recently added sets page and Atom feed for newly published sets.
- **[Issue #76]** Push GA4 events onto the GTM dataLayer for the homepage call-to-action links, so the homepage conversion can be marked as a key event in Analytics.
    - The GTM trigger, tag and GA4 key-event toggle are still manual, one-time steps in the Google UI; `docs/ANALYTICS.md` walks through them.

### Changed

- **[Issue #407]** Remove the certbot call from the container entrypoint so startup no longer waits on certificate renewal.
    - A certificate must already be present on the mounted `/etc/letsencrypt` volume before the container starts, since nginx will not start without one; see `docs/TLS-CERTIFICATES.md` for bootstrapping a brand-new host.
- **[Issue #466]** Replace the Laravel-skeleton identity in `composer.json` with real project metadata and remove the dead `wpackagist.org` repository and stray `wordpress` droplet tag.
    - `composer.lock`'s `content-hash` and `plugin-api-version` are regenerated; no package versions change.
- **[Issue #502]** Point the `.env.local` header at the root `.env` for pinning a stable `APP_KEY`.
- **[Issue #523]** Run the build-and-test and secret-scan workflows on `merge_group` events so a merge queue can require their checks.
- **[Issue #534]** Link the Recently added sets page from the header navigation and home page, and advertise its Atom feed on every page.

### Removed

- **[Issue #76]** Remove the hard-coded Universal Analytics (`UA-`) snippet, which had been sending requests nowhere since Google stopped processing Universal Analytics hits in July 2023. GA4 continues to load through the existing Google Tag Manager container.

### Fixed

- **[Issue #447]** Add the back-merge and changelog-fragment workflows to `main` so they run at all — GitHub only triggers `push` workflows from the default branch, so the automation meant to keep `develop` in sync with `main` had never been able to fire.
- **[Issue #502]** Pass a root `.env` `APP_KEY` through to the local app container so a pinned key survives restarts.
- **[Issue #542]** Collate `changelog.d/` fragments into a versioned `CHANGELOG.md` section after each merge to `main` and tag the release on that commit.
    - The first release after this ships collates the whole fragment backlog under its own version.

### Security

- **[Issue #424]** Clear both critical npm advisories and the axios high-severity backlog, and unblock Dependabot CI by dropping an unused stale credential from the test build.
    - The complementary fix is operator-side: the repo-level Dependabot secrets `COMPOSER_TOKEN`, `DOCKER_USERNAME` and `DOCKER_PASSWORD` date from 2023-12-21 and should be deleted so the fresher org-level values apply.
- **[Issue #425]** Add an MIT LICENSE, rewrite `.env.example` around the real variables, and generate dev TLS certs locally instead of committing them.
    - Run `make certs` (or any `make up*` target) once after pulling; a bare `docker compose up` now fails until certs exist.
- **[Issue #426]** Move the newsletter signup behind a rate-limited server-side Brevo proxy so no API key can reach the browser bundle.
    - Requires a new unprefixed `BREVO_API_KEY` in the deploy environment; the old `MIX_SENDINBLUE_API_KEY` is removed and must not be re-added.
- **[Issue #430]** Remove every committed `APP_KEY` literal and deliver the production key through the existing GitHub-secrets path, with Laravel-aware secret scanning in CI.
    - Requires an `APP_KEY` repository secret and a rotated key on the host before the next deploy; deploys now fail fast without one, and rotation logs every user out.
- **[Issue #431]** Pin every third-party GitHub Action that receives a deployment secret to an immutable commit SHA, and move the DigitalOcean API token from a command-line argument to an environment variable.
    - Two actions (`avakar/set-deployment-status@v1`, `avakar/create-deployment@v1`) were pinned to a branch named `v1`, not a tag — same mutable-ref risk as `@master`.
- **[Issue #435]** Stop publishing the Composer GitHub token in the Docker image: it is now a BuildKit secret rather than a build ARG, so it no longer appears in `docker history` layer metadata, and `composer config --global` plus a same-layer `rm` keeps `auth.json` out of the shipped filesystem.
    - Local `make up` builds no longer embed the developer's personal token either; `docker-compose.yml` sources the same secret from the `COMPOSER_TOKEN` environment variable, and an unset one is a no-op because both Composer VCS sources are public.
    - The complementary fix is operator-side: the token readable in already-published image tags must be revoked, and those tags purged or rebuilt.
- **[Issue #460]** Default the local full-stack environment to the `log` mail driver and externalize the last hardcoded Mailgun value, so no Mailgun credential is needed for local development.
    - The exposed Mailgun key still requires rotation in the Mailgun account; this change only removes the need for it locally.
- **[Issue #461]** Remove the orphaned Dusk compose stack that carried a committed Trading Card API client ID and secret, and record the verification that the pair was a testing-only seeder fixture.
    - The same credential pair is still committed in `cardtechie/tradingcardapi-admin` and `cardtechie/cardtechie-site`, which need their own fixes.
- **[Issue #462]** Add the operator tooling and runbook for purging historical secrets from git history before the repo is made public.
    - Ships tooling and documentation only; the rewrite and force-push remain a manual operator step, gated on rotation of the credentials still live in history.
- **[Issue #463]** Audit the tracked `.env.local`, document that it is intentionally tracked with repository-default values only, and add a gitleaks rule scoped to the file so a real secret added later is caught by CI.
- **[Issue #469]** Add a `SECURITY.md` disclosure policy naming a real private reporting address, and repoint the README's Security section at it.
    - GitHub private vulnerability reporting stays unavailable until the repository is public; enable it at that flip.
- **[Issue #470]** Add a secret-scanning and push-protection runbook plus a scheduled guard that fails once the repo is public and either setting is off.
    - Enabling the settings is an operator action in repo Settings; the guard only reports drift, and needs the `PROJECT_TOKEN` org secret because `security_and_analysis` is admin-only.
- **[Issue #472]** Bump composer and npm lock files to clear known high-severity advisories, and exempt Dependabot PRs from the changelog-fragment CI gate.
    - Advisories cleared: `laravel/framework`, `symfony/http-foundation`, `symfony/mime`, `guzzlehttp/guzzle`, `league/commonmark`, `phpunit/phpunit` (composer); `fast-uri`, `brace-expansion`, `minimatch`, `node-forge`, `immutable`, `nanoid`, `browserslist`, `postcss`, `svgo`, `serialize-javascript` (npm).
- **[Issue #484]** Promote GitHub Private Vulnerability Reporting to the preferred disclosure channel in `SECURITY.md`, now that the repo is public and the feature is enabled.
    - Email remains the fallback channel for anyone who cannot use GitHub's reporting flow.
- **[Issue #494]** Remove the one-time history-purge tooling from the repository ahead of the public release.
- **[Issue #495]** Remove production DB coordinates from the purge runbook and add the missing WordPress salts to the purge generator.
    - Take the #494 backup mirror only after this merges; before it, the generator excluded the DB username and database name as present-at-head.
- **[Issue #507]** Remove the business strategy document from the repository and fold its history removal into the #494 purge run.
- **[Issue #513]** Record the accept-in-history decision for three benign dev TLS private keys left in git history after the #494 purge.
    - Documentation only — no purge, no code change; the decision replaces the now-relocated `docs/SECRET-HISTORY-PURGE.md` runbook as the durable record.
- **[Issue #537]** Pin PHP to 8.2.35 and disable session upload progress to fix PHP2Shell (CVE-2026-109618/109619).

## [0.2.7] - 2025-10-10

### Changed

- Improve release notes to use CHANGELOG.md content (#349, #350)
    - Release notes now automatically extract from CHANGELOG.md
    - Falls back to git commit analysis if version not in CHANGELOG
    - Maintains single source of truth for release information

## [0.2.6] - 2025-10-09

### Changed

- Configure Dependabot to only create PRs for security updates (#336, #348)

## [0.2.5] - 2025-10-09

### Changed

- Updated all dependencies to latest versions (#335, #343)
    - GitHub Actions: checkout v5, login-action v3, build-push-action v6
    - NPM: prettier 3.6.2, bootstrap 5.3.8, sass 1.93.2, vue 3.5.22, and more
    - Composer: guzzlehttp 7.10.0, laravel 12.33.0, phpunit 11.5.42, symfony 7.3.4
    - 54 transitive composer dependency updates

### Fixed

- Mix manifest error in blog build configuration (#343)
- Tailwind CSS v3 compatibility (deferred v4 upgrade to #344)
- tw-elements v2.0.0 plugin path

## [0.2.4] - 2025-10-08

### Fixed

- Docker tagging invalid reference format (#342)

## [0.2.3] - 2025-10-08

### Added

- GitHub Actions build status documentation

### Fixed

- GitHub Actions build failure: Removed Claude API key dependency (#340)

## [0.2.2] - 2025-10-07

### Fixed

- GitHub Actions workflow tag format (#338)
- Removed v prefix from release tags to match project convention

## [0.2.1] - 2025-10-07

### Fixed

- Version script tagging logic to work with project's tagging convention (#334)
- Hotfix branch version detection

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

[Unreleased]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.37...HEAD
[0.2.37]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.7...0.2.37
[0.2.7]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.6...0.2.7
[0.2.6]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.5...0.2.6
[0.2.5]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.4...0.2.5
[0.2.4]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.3...0.2.4
[0.2.3]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.2...0.2.3
[0.2.2]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.1...0.2.2
[0.2.1]: https://github.com/cardtechie/cardalmanac-app/compare/0.2.0...0.2.1
[0.2.0]: https://github.com/cardtechie/cardalmanac-app/releases/tag/0.2.0
