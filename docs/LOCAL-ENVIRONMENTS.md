# Local Development Environments

This document describes setup and different local development environments available for the Card Almanac application.

## Initial Setup

To setup the Card Almanac to work with the Trading Card API, create a `.env` file with the following variables set:

```dotenv
# Trading Card API Configuration
TRADINGCARDAPI_CLIENT_ID=<your client ID>
TRADINGCARDAPI_CLIENT_SECRET=<your client secret>

# Brevo (formerly SendinBlue) Integration (for the newsletter signup).
# Deliberately not MIX_-prefixed: Laravel Mix inlines every MIX_* variable
# into the public JS bundle, which would publish the key (#426).
BREVO_API_KEY=<your brevo api key>
```

## Application Keys

`APP_KEY` is **not committed to this repository** (#430). Nothing needs to be set
up for it locally: the local and test entrypoints source
`.docker/scripts/ensure-app-key.sh`, which exports a freshly generated ephemeral
key whenever `APP_KEY` is unset or empty.

The practical consequence is that the key changes on every container start, so
existing session cookies stop decrypting and you are logged out after a
`make up`. To keep a stable session across restarts, pin one in your own
untracked `.env`:

```bash
# Generate once, then paste into .env (which is gitignored).
echo "APP_KEY=base64:$(head -c 32 /dev/urandom | base64)"
```

The `tcapi` and `admin` services in the full stack no longer receive an `APP_KEY`
from this repository at all. Each runs another project's image, and each of those
images ships its own local key in its own baked `.env`; setting the variable here
-- even to an empty string -- would shadow it, because Laravel's immutable
`Dotenv` will not overwrite an environment variable that is already present, and
the container would boot into "No application encryption key has been specified".
If one of those containers ever does need a specific key, set it in that
project's repository rather than here.

In production the key is supplied by the `APP_KEY` repository secret, written
into `cardalmanac.env` by `.github/workflows/deployment.yaml` and read by
Compose when `deploy.sh` brings the stack up. `.docker/prod.docker-compose.yaml`
declares it as a mandatory substitution, so a deploy with the secret missing
fails loudly rather than silently falling back to some other key.

## Local Mail

The full stack's `admin` container defaults to the `log` mail driver, so mail is
written to the container log instead of being delivered and **no credential is
required** for local development. No Mailgun credential is committed to this
repository.

To exercise real Mailgun delivery locally, set all three variables in your own
untracked root `.env`:

```dotenv
MAIL_DRIVER=mailgun
MAILGUN_DOMAIN=<your mailgun sending domain>
MAILGUN_SECRET=<your mailgun api key>
```

Compose substitutes them into the `admin` service; leaving them unset keeps the
`log` default.

## Environment Overview

The Card Almanac project supports multiple local development configurations to match different development needs:

- **⚡ Minimal Almanac**: Lightweight almanac development (almanac + database only)
- **🔧 Full Development**: Complete local stack with all services

## Environment Configurations

### 1. Minimal Almanac (Almanac Only)

**Use Case**: Lightweight almanac development without additional services

```bash
docker compose up -d
```

Or

```bash
make upd
```

**What runs locally:**

- ✅ Card Almanac app (8541) <https://cardalmanac.dev:8541/>
- ✅ MySQL database (13307)

**External dependencies:**

- 🌐 Trading Card API (`host.docker.internal:8243`)

**Best for:**

- Almanac UI/UX development
- Database schema changes
- Fast iteration on almanac features
- Minimal resource usage
- Quick development cycles
- Testing almanac changes independently

---

### 2. Full Development Stack

**Use Case**: Complete local development with all services

```bash
make upd-full  # Uses .docker/docker-compose.full.yml
```

**What runs locally:**

- ✅ Card Almanac app (8541) <https://cardalmanac.dev:8541/>
- ✅ Trading Card API (8243) <https://api.tradingcardapi.dev:8243/>
- ✅ Admin interface (8480) <https://admin.tradingcardapi.dev:8480/>
- ✅ MySQL database (13307)

**External dependencies:** None

**Best for:**

- Full-stack feature development
- Almanac + API integration work
- Testing complete workflows
- Debugging cross-service issues
- Admin interface development
- Testing API hotfixes and custom branches
- End-to-end testing

## Configuration Files

| File                              | Purpose                         | Environment      |
| --------------------------------- | ------------------------------- | ---------------- |
| `docker-compose.yml`              | Base almanac services (minimal) | Minimal Almanac  |
| `.docker/docker-compose.full.yml` | Adds API + Admin                | Full Development |
| `.env.local`                      | Default configuration           | Development      |
| `.gitleaks.toml`                  | Secret-scanning rules (CI gate) | All              |

### Browser tests and the removed Dusk stack

This repository ships **no Laravel Dusk stack**. `laravel/dusk` is not a
dependency, `tests/Browser/` does not exist, and the `.docker/dusk.*` compose
files it once carried were an unwired copy of another repository's stack — four
of their bind mounts pointed at paths that do not exist here. They were removed
in #461. Browser coverage for the Trading Card API lives in
`cardtechie/tradingcardapi-admin`.

The `TRADINGCARDAPI_CLIENT_ID` / `TRADINGCARDAPI_CLIENT_SECRET` pair formerly
committed in that compose file was a fixture for the API's `ClientTokenSeeder`,
which refuses to run unless `APP_ENV=testing` — no automated path could insert
it into a production database. The literals themselves were replaced with
environment substitutions in #430. Local and full-stack runs read both values
from the developer's `.env`, as **Initial Setup** above describes. The
`make up` / `upd` / `up-full` / `upd-full` targets fall back to `.env.local`
when no `.env` is present, so either file can supply the pair.

## Port Reference

| Environment          | Almanac | API      | Admin | MySQL |
| -------------------- | ------- | -------- | ----- | ----- |
| **Minimal Almanac**  | 8541    | External | -     | 13307 |
| **Full Development** | 8541    | 8243     | 8480  | 13307 |

## Common Workflows

### 🚀 Quick Almanac Development

```bash
# Start minimal stack (almanac + database only)
docker compose up -d

# Access almanac at https://localhost:8541
# Uses external API automatically
```

### 🔧 Full-Stack Development

```bash
# Start complete local stack
make upd-full

# Almanac: https://localhost:8541
# API: https://localhost:8243
# Admin: https://localhost:8480
```

### 🧪 Testing API Changes

```bash
# Test API changes with full local stack
make upd-full

# Test specific API branch/tag
DOCKER_TAG_TCAPI=my-hotfix-branch make upd-full

# Test at https://localhost:8541
```

### 🐛 Debugging API Integration

```bash
# Start with local API for debugging
make upd-full

# Make API changes and restart API container
docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml restart tcapi

# Test integration at https://localhost:8541
```

### 🎨 Almanac UI Development

```bash
# Start minimal environment for UI work
make upd

# Make UI changes, they hot-reload automatically
# Test against external API (no local API needed)
```

## Environment Variables

### Minimal Almanac (.env.local)

```bash
APP_KEY=                                              # Blank: generated per container
TRADINGCARDAPI_URL=https://host.docker.internal:8243  # External API
DB_HOST=mysql
DB_DATABASE=tradingcards
```

`.env.local` is baked into the image as `.env` (`Dockerfile:195`), so a value
committed there would become every container's fallback key. It is deliberately
left blank -- see [Application Keys](#application-keys).

### Full Development (values seen by the containers)

`.docker/docker-compose.full.yml` supplies these, but not all from the same
place. The first three are hardcoded in the compose file; the `MAIL_*` entries
are `${VAR:-default}` substitutions read from your untracked root `.env`, and
the values shown are what you get when it leaves them unset.

```bash
TRADINGCARDAPI_URL=https://tcapi:443  # Set in the compose file
DB_HOST=mysql                         # Set in the compose file
DB_DATABASE=tradingcards              # Set in the compose file
MAIL_DRIVER=log                       # From root .env; default: mail goes to the container log
MAILGUN_DOMAIN=                       # From root .env; blank unless opting into Mailgun
MAILGUN_SECRET=                       # From root .env; blank unless opting into Mailgun
```

To change a `MAIL_*` value, edit your root `.env` -- not the compose file. See
[Local Mail](#local-mail) for the Mailgun opt-in.

## Pointing the App at a Live or Staging API

Some checks have to run against a real API rather than a local stack — notably
the browse-count capture in
[DRAFT-STATUS-GATE-VERIFICATION.md](DRAFT-STATUS-GATE-VERIFICATION.md), whose
whole point is that a real request carrying the real token is the only thing
that can observe a silent server-side gate.

Set these in your untracked `.env` and restart the container:

```dotenv
TRADINGCARDAPI_URL=https://api.tradingcardapi.com
TRADINGCARDAPI_CLIENT_ID=<the client id for that environment>
TRADINGCARDAPI_CLIENT_SECRET=<the client secret for that environment>
```

Then run the capture inside the app container:

```bash
docker compose exec caapp php artisan browse:capture-counts \
  --set=<a set id with a checklist> \
  --out=storage/app/browse-counts-before.json
```

Notes:

- **Credentials are per environment.** A local client id will authenticate
  against a local API and fail against a remote one; the capture records the
  failure rather than aborting, so check the artifact's `failures` map before
  trusting a run.
- **`TRADINGCARDAPI_SSL_VERIFY` should stay `true`** against a real API. It
  exists for local instances without a valid certificate, and turning it off
  against a remote host hides a genuine trust failure.
- **The artifact records `TRADINGCARDAPI_URL` in its header**, so a capture
  taken against the wrong environment is detectable after the fact — and
  `browse:capture-counts --compare` warns when two artifacts disagree on it.

## Choosing the Right Environment

| Scenario                 | Recommended Environment | Command                                        |
| ------------------------ | ----------------------- | ---------------------------------------------- |
| Almanac UI changes       | Minimal Almanac         | `make upd`                                     |
| API integration work     | Full Development        | `make upd-full`                                |
| Admin interface work     | Full Development        | `make upd-full`                                |
| Testing API changes      | Full Development        | `make upd-full`                                |
| Hotfix validation        | Full Development        | `DOCKER_TAG_TCAPI=hotfix-branch make upd-full` |
| Database migrations      | Minimal or Full         | `make upd` or `make upd-full`                  |
| Performance testing      | Full Development        | `make upd-full`                                |
| Set browsing development | Minimal Almanac         | `make upd`                                     |
| Checklist functionality  | Minimal or Full         | `make upd` or `make upd-full`                  |

## Benefits

- ✅ **Flexible development** - Choose the right environment for your task
- ✅ **Resource efficient** - Run only what you need for almanac development
- ✅ **Simple setup** - Just two environments to understand
- ✅ **Easy testing** - Switch environments as needed
- ✅ **Backward compatible** - Existing workflows unchanged
- ✅ **Independent development** - Work on almanac without running full stack
- ✅ **Cross-project consistency** - Matches admin and API project patterns

## Troubleshooting

### External API Connection Issues

If the minimal environment can't connect to the external API:

1. Ensure the external API is running at `host.docker.internal:8243`
2. Check your `.env` file has correct `TRADINGCARDAPI_CLIENT_ID` and `TRADINGCARDAPI_CLIENT_SECRET`
3. Verify firewall settings allow Docker to access host network

### Full Stack Issues

If the full environment has problems:

1. Check all services are running: `docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml ps`
2. View logs: `docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml logs`
3. Restart specific service: `docker compose -f docker-compose.yml -f .docker/docker-compose.full.yml restart caapp`

### Database Issues

For database problems in either environment:

1. Reset database: `make clean-docker` (warning: destroys all data)
2. Check MySQL logs: `docker compose logs mysql`
3. Connect to database: `docker compose exec mysql mysql -u root -p`
