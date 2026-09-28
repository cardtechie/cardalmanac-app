# Security Policy

Card Almanac (`cardtechie/cardalmanac-app`) is a deployed web application. We take
its security seriously and appreciate responsible disclosure of any vulnerabilities
you find.

## Reporting a vulnerability

Please do **not** report security vulnerabilities through public GitHub issues,
discussions, or pull requests.

Instead, email [security@cardtechie.com](mailto:security@cardtechie.com). This is the
same address used for every CardTechie project, and it is the channel to use today.

> **A note on GitHub private vulnerability reporting.** This repository is currently
> private, and GitHub's private vulnerability reporting (Security tab → **Report a
> vulnerability**) is only available on public repositories. It is therefore **not**
> available here yet. When this repository is made public, that flow becomes the
> preferred channel and this policy will be updated to say so; until then, email is
> the only private channel.

When reporting, please include as much of the following as you can:

- A description of the vulnerability and its potential impact.
- Steps to reproduce, or a proof-of-concept.
- The affected version or deployment (release tag, or the production site).
- Any suggested remediation, if you have one.

## Response times

We aim to respond promptly to every report:

- **Acknowledgement** within **3 business days** of receiving your report.
- **Initial assessment** (severity and a remediation plan) within
  **7 business days**.

If you do not receive an acknowledgement within 3 business days, please follow up by
email in case the report was missed.

## Coordinated disclosure

We follow a coordinated-disclosure process:

1. We confirm the vulnerability and determine the affected versions.
2. We develop and test a fix, and prepare a security advisory.
3. We release the fix and publish the advisory, crediting you for the report
   unless you prefer to remain anonymous.

Please keep the details of any vulnerability private until a fix has been released.
We ask for up to **90 days** to ship a fix before public disclosure and will keep you
informed of our progress throughout.

## Supported versions

Card Almanac is a deployed application rather than a distributed package, so there is
no matrix of installable versions to support. Security fixes land on the **latest
released tag line** and are deployed to the running production site at
[cardalmanac.com](https://cardalmanac.com).

| What                               | Supported          |
| ---------------------------------- | ------------------ |
| Production deployment              | :white_check_mark: |
| Latest released tag (`0.2.x` line) | :white_check_mark: |
| Older tags                         | :x:                |

Older tags do not receive security fixes and are not redeployed. If you are running
your own copy of this application, track the latest tag.

## Scope

This policy covers the Card Almanac application in this repository only. It does
**not** cover the upstream Trading Card API service, which Card Almanac consumes as a
client — please report findings in that service through its own channels.

## Development TLS certificates (not a vulnerability)

Earlier revisions of this repository committed self-signed TLS certificates and their
private keys for local development, so they remain in git history. Since
[#425](https://github.com/cardtechie/cardalmanac-app/issues/425) they are no longer
committed: each developer generates their own with `make certs`
(`.docker/scripts/generate-dev-certs.sh`), and the generated files are excluded by
`.gitignore` and `.dockerignore`.

Secret scanners may flag the historical keys, but they are **not credentials for any
real service** and grant access to nothing:

| File (history only)                                | Hostname                   | Status                     |
| -------------------------------------------------- | -------------------------- | -------------------------- |
| `.docker/cert/cardalmanac.dev.{crt,key}`           | `cardalmanac.dev`          | Valid until **2026-10-08** |
| `.docker/api/api.tradingcardapi.dev.{crt,key}`     | `api.tradingcardapi.dev`   | Expired **2022-10-27**     |
| `.docker/admin/admin.tradingcardapi.dev.{crt,key}` | `admin.tradingcardapi.dev` | Expired **2022-11-13**     |

All three are self-signed for `*.dev` hostnames that resolve only on a developer's own
machine (see [docs/LOCAL-ENVIRONMENTS.md](docs/LOCAL-ENVIRONMENTS.md)). They are not
issued by any certificate authority, are not trusted by any browser or client by
default, and are unrelated to the production certificate, which is issued by Let's
Encrypt and lives only on the production host (see
[docs/TLS-CERTIFICATES.md](docs/TLS-CERTIFICATES.md)). Reports that these historical
keys are exposed secrets will be closed with a pointer to this section.
