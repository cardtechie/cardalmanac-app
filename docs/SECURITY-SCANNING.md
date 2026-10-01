# Security Scanning

Operator runbook for GitHub-native secret scanning and push protection on `cardtechie/cardalmanac-app`, and how they layer with the gitleaks scan that already runs in CI.

Enabling these settings is a **repository settings change**. No pull request can make it — this document tells you exactly what to change, when to change it relative to the public-visibility flip, and what to expect from the first scan. The scheduled guard in `.github/workflows/security-settings-guard.yaml` is what stops the settings quietly drifting back off afterwards.

Tracking issue: [#470](https://github.com/cardtechie/cardalmanac-app/issues/470). Part of the public-release gate.

## Current state

Read from the GitHub API on **2026-09-08**. Re-read it with the command under [Verifying](#verifying) before acting on anything below — if it has drifted, trust the API, not this table.

| Setting                                 | Status        |
| --------------------------------------- | ------------- |
| Repository visibility                   | `private`     |
| `secret_scanning`                       | `disabled`    |
| `secret_scanning_push_protection`       | `disabled`    |
| `secret_scanning_non_provider_patterns` | `disabled`    |
| `secret_scanning_validity_checks`       | `disabled`    |
| `code_security`                         | `disabled`    |
| `dependabot_security_updates`           | **`enabled`** |

Organisation defaults for **new** repositories in `cardtechie` (plan: enterprise):

| Org default                                                    | Status  |
| -------------------------------------------------------------- | ------- |
| `advanced_security_enabled_for_new_repositories`               | `false` |
| `secret_scanning_enabled_for_new_repositories`                 | `false` |
| `secret_scanning_push_protection_enabled_for_new_repositories` | `false` |

## What to enable, and when

**Enable secret scanning and push protection at the moment of the visibility flip, or immediately after it — not before.** GitHub-native secret scanning on a **private** repository requires a GitHub Advanced Security / Secret Protection license, and the org does not enable it for new repositories. The operator has confirmed on [#470](https://github.com/cardtechie/cardalmanac-app/issues/470) that this can only be done once the repo is public.

That ordering has a consequence worth stating plainly: there is no window in which push protection guards this repository while it is still private. The protection that covers the private window is the gitleaks job described under [How this layers with gitleaks](#how-this-layers-with-gitleaks), which runs on every pull request and every push to `main` and `develop` regardless of visibility.

**Flipping to public does not turn push protection on by itself.** The org's existing public repository `cardtechie/tradingcardapi-sdk-php` reads `secret_scanning: enabled` but `secret_scanning_push_protection: disabled` — scanning came on with the flip, push protection did not. Push protection is a separate, explicit toggle.

So the sequence is:

1. Flip `cardtechie/cardalmanac-app` to public.
2. Immediately enable secret scanning **and** push protection (below).
3. Read the settings back and confirm both report `enabled`.
4. Triage the alerts the first scan raises (below).
5. Only then treat the flip as complete. The guard workflow is the durable check: once the repo is public it fails if either setting is off.

## Enabling

In the UI: **Settings → Code security**, then enable **Secret scanning** and, under it, **Push protection**.

Equivalently, via the API:

```bash
gh api -X PATCH repos/cardtechie/cardalmanac-app \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

### Verifying

```bash
gh api repos/cardtechie/cardalmanac-app --jq .security_and_analysis
```

Both `secret_scanning.status` and `secret_scanning_push_protection.status` must read `enabled`.

`security_and_analysis` is only returned to a caller with **repository admin** access. If the block comes back `null` or absent, that means the token cannot read it — it does **not** mean the settings are off. Re-run with an admin-scoped token before drawing any conclusion.

## The drift guard

`.github/workflows/security-settings-guard.yaml` runs weekly and on manual dispatch. It reads the repository's visibility and both settings and applies one rule:

- **Repository is not public** — emits a notice and passes. This is the expected pre-flip state, and Secret Protection may not be licensed for a private repository.
- **Repository is public** — fails unless both secret scanning and push protection report `enabled`.
- **`security_and_analysis` cannot be read** — fails with an explicit "insufficient token scope" message, so a token problem is never mistaken for the settings being disabled.

It deliberately does **not** run on pull requests: the settings are repository-global, so a per-PR run would tell you nothing about the PR and would sit permanently red until the flip.

The job authenticates with the `PROJECT_TOKEN` organisation secret, because the default `GITHUB_TOKEN` cannot read `security_and_analysis`. If `PROJECT_TOKEN` turns out not to carry repo-admin scope here, the workflow fails with the cannot-read message above; widen the token, or fall back to running the [verification command](#verifying) by hand.

Dispatch it manually with:

```bash
gh workflow run security-settings-guard.yaml --repo cardtechie/cardalmanac-app
gh run list --workflow security-settings-guard.yaml --repo cardtechie/cardalmanac-app --limit 1
```

## Expected first-scan triage

The first scan after enabling may flag the self-signed development TLS private keys under `.docker/cert/`, `.docker/api/`, and `.docker/admin/` (`*.key`) in **git history**. They were committed before [#425](https://github.com/cardtechie/cardalmanac-app/issues/425); since #425 they are generated locally by `make certs`, ignored by `.gitignore` and `.dockerignore`, and no longer allowlisted in `.gitleaks.toml`.

**These are benign.** They are self-signed certificates for the local-only development hostnames `cardalmanac.dev`, `api.tradingcardapi.dev`, and `admin.tradingcardapi.dev`; they are valid for no public hostname, and no production certificate is tracked in this repository — production certs live on the host and are mounted at runtime.

Disposition:

- Close history-only alerts on those keys as **used in tests** / not a real credential.
- The explanatory note for readers belongs in `SECURITY.md`, which [#469](https://github.com/cardtechie/cardalmanac-app/issues/469) owns. Do not add it here.

Anything flagged that is **not** one of those historical `.key` files — including a `.key` file in the current tree — should be treated as a live secret: rotate first, then remove it from the tracked tree.

## Git history purge: these three keys are out of scope (#513)

**Decision: accept in history** — these three keys were deliberately excluded from the [#494](https://github.com/cardtechie/cardalmanac-app/issues/494) history purge, not an oversight.

The [#494](https://github.com/cardtechie/cardalmanac-app/issues/494) purge succeeded for its four primary targets (`.claude/PROJECT-OVERVIEW.md`, `prod.docker-compose.yaml`, `docker-compose.full.yml`, `dusk.docker-compose.yaml` — all now 0 commits on `origin/main`'s history). Three self-signed development TLS private keys still have commits on `origin/main`'s history (re-verified via `git log --follow`):

| Path                                         | Commits on `origin/main` history |
| -------------------------------------------- | -------------------------------- |
| `.docker/cert/cardalmanac.dev.key`           | 3                                |
| `.docker/api/api.tradingcardapi.dev.key`     | 2                                |
| `.docker/admin/admin.tradingcardapi.dev.key` | 2                                |

**Why accept rather than purge:**

- These are **self-signed development certificates** for local `.dev` hostnames ([#469](https://github.com/cardtechie/cardalmanac-app/issues/469), `SECURITY.md` → [Development TLS certificates](../SECURITY.md#development-tls-certificates-not-a-vulnerability)). They are valid for no public hostname.
- They were **removed from the working tree** by [#425](https://github.com/cardtechie/cardalmanac-app/issues/425); developers now generate their own via `.docker/scripts/generate-dev-certs.sh` (see [`docs/TLS-CERTIFICATES.md`](TLS-CERTIFICATES.md)).
- **No production certificate has ever been committed** — production certs are mounted from the host.
- **GitHub secret scanning reports zero alerts** on this repository.
- Purging `origin/main`'s history on a now-public repository is itself the higher-cost operation — a forced rewrite invalidates every existing clone and fork and breaks any external reference to the affected commit SHAs — for a reduction in risk that is already close to zero.

**Where this decision now lives.** [#509](https://github.com/cardtechie/cardalmanac-app/issues/509) drafted this exact answer, but was closed `NOT_PLANNED` because the runbook that would have recorded it, `docs/SECRET-HISTORY-PURGE.md`, is moving to the private `cardtechie-ops` repo and is already gone from `main`. This section is the durable, public replacement for that record — recording the disposition decision here adds no new exposure, since the paths, the historical commit counts, and the "these are benign" explanation are already public via `SECURITY.md` and the triage section above.

Any future purge of `origin/main`'s history should include these three paths in its `REMOVED_PATHS` / `--invert-paths` scope only if this section is explicitly revisited and updated.

## Known limitation

Pattern-based native scanning would not have caught three of the four secrets the public-release audit found. The DigitalOcean database password, the Mailgun key ([#460](https://github.com/cardtechie/cardalmanac-app/issues/460)), and the Passport client secret ([#461](https://github.com/cardtechie/cardalmanac-app/issues/461)) were plain `KEY: value` pairs in YAML rather than recognisable token formats, so no provider pattern matched them.

Native scanning is a **backstop**, not the primary defence. It is worth enabling — it catches the token-shaped classes cheaply and, with push protection, catches them before they land — but it does not replace keeping credentials out of tracked files.

## How this layers with gitleaks

`.github/workflows/secret-scan.yaml` runs `gitleaks` against the working tree on every pull request and every push to `main` and `develop`, using the repository's own `.gitleaks.toml`. That config extends the upstream rule set with three Laravel-aware rules written specifically for the `KEY: value` shapes above:

- `laravel-app-key` — `APP_KEY` / `*_CIPHER_KEY` / `*_ENCRYPTION_KEY` assigned a `base64:`-prefixed value, in dotenv or YAML form.
- `mailgun-legacy-private-key` — Mailgun legacy `key-`-prefixed API keys.
- `generic-base64-secret-assignment` — any `*_SECRET` assigned a `base64:`-prefixed value.

The scan covers the **working tree only** (`gitleaks dir`), never history. That is deliberate: the historical production `APP_KEY` was rotated in [#430](https://github.com/cardtechie/cardalmanac-app/issues/430) and is now inert, that issue explicitly rules out a history rewrite, and a history-wide scan would therefore fail forever on a dead key.

The layers:

| Layer                  | Covers                                          | Runs                                    |
| ---------------------- | ----------------------------------------------- | --------------------------------------- |
| gitleaks CI scan       | Laravel `KEY: value` shapes + upstream defaults | Every PR and push to `main` / `develop` |
| GitHub secret scanning | Provider token patterns, with validity checks   | Continuously, once the repo is public   |
| GitHub push protection | The same provider patterns, blocked **at push** | Continuously, once the repo is public   |

## Dependabot

Dependabot security updates are **already enabled** on this repository — verified against the API on 2026-09-08. No action is needed. It is recorded here only because the setting lives alongside the two above in **Settings → Code security**, so it is easy to assume it needs the same treatment.
