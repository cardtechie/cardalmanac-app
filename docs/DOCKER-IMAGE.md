# Docker image

The `Dockerfile` is a multi-stage build. Every consumer names the stage it
wants; nothing relies on "whatever the file happens to end with".

## Stage graph

```text
php:8.2-fpm ──> base ──┬──> vendor ──┐
                       │             │
                       ├──> dev      ├──> runtime   (final stage; what ships)
                       │             │
node:20-bookworm-slim ─┴──> assets ──┘
```

| Stage     | Built from              | Contains                                                                                                                        | Who builds it                                    |
| --------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| `base`    | `php:8.2-fpm`           | PHP extensions, nginx, supervisor, certbot, curl, the nginx/php/supervisor config. No compilers we added, no Node, no Composer. | Nothing directly — the shared parent.            |
| `assets`  | `node:20-bookworm-slim` | The front-end toolchain and the compiled bundle. Discarded after its output is copied out.                                      | Nothing directly — an input to `runtime`.        |
| `vendor`  | `base`                  | Composer plus a `--no-dev` vendor tree and the optimized autoloader. Discarded after its output is copied out.                  | Nothing directly — an input to `runtime`.        |
| `dev`     | `base`                  | The full toolchain: compilers, `-dev` headers, Xdebug, Node, Composer, dev Composer deps, `node_modules`.                       | Local development (`make up`) and CI's test job. |
| `runtime` | `base`                  | Application code, `--no-dev` vendor, compiled assets. Nothing that only exists to build.                                        | The release build.                               |

`runtime` must stay the **last** stage in the file, so an untargeted
`docker build` produces the slim image rather than the fat one. The release
workflow also names `target: runtime` explicitly, so a later reorder cannot
silently start publishing `dev`.

## Which target each consumer builds

| Consumer                                 | Target    | Why                                                                                                            |
| ---------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------- |
| `docker-compose.yml` (`make up` / `upd`) | `dev`     | `local.provision-packages.sh` rsyncs `/var/www/vendor` and `/var/www/node_modules` into the bind-mounted tree. |
| `.github/workflows/build-and-test.yaml`  | `dev`     | `npm test` runs prettier out of `node_modules` and `composer lint` out of the dev vendor tree.                 |
| `.github/workflows/build-release.yaml`   | `runtime` | This is the published image.                                                                                   |

`.docker/tests.docker-compose.yaml` and `.docker/prod.docker-compose.yaml`
reference images by tag only, so they need no target.

## The Composer token

`COMPOSER_TOKEN` is a **BuildKit secret**, never a build `ARG`. `docker history`
renders `ARG` values in plaintext, so an `ARG` publishes the credential in the
image's layer metadata for anyone who can pull it.

Locally the token is read from the environment (the `.env` / `.env.local` export
the makefile already does) and declared in `docker-compose.yml`:

```yaml
secrets:
    composer_token:
        environment: COMPOSER_TOKEN
```

For a direct `docker build`:

```bash
DOCKER_BUILDKIT=1 docker build --target runtime -t caapp:local \
  --secret id=composer_token,env=COMPOSER_TOKEN .
```

The token is **optional**. Both VCS repositories in `composer.json`
(`picklewagon/laravel-commonmark-blog`, `cardtechie/tradingcardapi-sdk-php`) are
public, so a build with no token succeeds and only risks anonymous GitHub API
rate limits. This is a change from the old build, which hard-failed without one.

## Decisions recorded

- **certbot stays in the runtime image.** `.github/workflows/renew-certificate.yaml`
  runs `docker exec <container> certbot renew` against the running production
  container, `.docker/prod.docker-compose.yaml` mounts `/etc/letsencrypt` into
  it, and `update.entrypoint.sh` calls `install-cert.sh`, which shells out to
  `certbot --nginx`. Removing certbot would break TLS renewal outright.
  Whether it can eventually leave is #420's question.
- **The MySQL client and `mysqldump` are removed.** They had no reference
  anywhere in the repo — no script, workflow, config, or application code.
- **Node moved from 16 to 20.** Node 16 reached end of life in September 2023.
  Node 20 is the LTS that `laravel-mix` 6 / webpack 5 build cleanly on, and the
  production asset build was verified on it in both the `assets` and `dev`
  stages.
- **`npm install`, not `npm ci`.** The committed `package-lock.json` is out of
  sync with `package.json`, so `npm ci` fails outright with a missing-from-lock
  error. Re-syncing the lockfile changes dependency resolution and belongs in
  its own change, so the `assets` stage keeps the old build's `npm install`.
- **`.prettierrc.json`, `.prettierignore`, `changelog.d/` and `CHANGELOG.md`
  stay in the image.** CI runs `npm test` inside the `dev` image and its
  `pretest` hook is `prettier --check .`, which reads its config and ignore list
  from the image. Excluding them would break the check outright — prettier would
  descend into `vendor/` and `node_modules/`.

## Keeping the header purge honest

`base` installs the `-dev` headers, compiles the PHP extensions, and purges the
headers **inside a single `RUN`**, so nothing that only exists to build survives
in the layer. Two details make that safe:

1. The `ldd` output is canonicalized with `readlink -f` before it is handed to
   `dpkg-query --search`. `ldd` reports libraries under `/lib/...` but a
   usrmerged Debian records them under `/usr/lib/...`, and `dpkg-query` no
   longer resolves the alias. Without the canonicalization every lookup misses,
   nothing is re-marked manual, and the purge takes `libzip5` with the headers —
   leaving a `zip.so` in the image that cannot load.
2. The same `RUN` ends with `php -m` assertions for `zip`, `pdo_mysql` and
   `OPcache`. If a future extension loses its runtime library to the purge, the
   build fails there instead of shipping a broken image.

## Verifying a build locally

```bash
# The shipped image
DOCKER_BUILDKIT=1 docker build --target runtime -t caapp:after \
  --secret id=composer_token,env=COMPOSER_TOKEN .

# Nothing that only exists to build should be present
docker run --rm --entrypoint sh caapp:after -c \
  '! command -v composer && ! command -v node && ! command -v npm && ! command -v mysqldump && echo OK'
docker run --rm --entrypoint sh caapp:after -c \
  '! test -d /var/www/app/node_modules && ! test -d /var/www/app/vendor/phpunit && echo OK'
docker run --rm --entrypoint sh caapp:after -c 'php -m' | grep -i xdebug && echo FAIL || echo OK

# certbot MUST still be there
docker run --rm --entrypoint sh caapp:after -c 'certbot --version'

# No credential in layer metadata
docker history --no-trunc caapp:after \
  | grep -iE 'composer_token|github-oauth|ghp_|github_pat_' && echo FAIL || echo OK

# The dev stage still satisfies CI
DOCKER_BUILDKIT=1 docker build --target dev -t picklewagon/cardalmanac-app:test \
  --secret id=composer_token,env=COMPOSER_TOKEN .
DOCKER_TAG_CAAPP=test docker compose -f .docker/tests.docker-compose.yaml run --rm caapp npm test
```

A boot smoke test needs a stand-in for the Let's Encrypt volume, because
`nginx-site-prod.conf` reads `/etc/letsencrypt/live/cardalmanac.com/*` and
`/etc/letsencrypt/options-ssl-nginx.conf`, which only exist on the production
host. Use `curl -4`: the prod server block declares `listen [::]:443` **without**
`ssl`, so the IPv6 listener is plaintext and an unqualified
`curl https://localhost/ping` fails the TLS handshake. `docker-compose.yml`'s
healthcheck already works around this with `-4`.

## Measuring the image

`docker image inspect --format '{{.Size}}'` reports the **compressed** content
size under the containerd image store. To compare against a figure taken with
the classic `docker images` SIZE column, sum the uncompressed layer sizes from
`docker history` instead. Note also that a local build on Apple silicon is
arm64 while CI publishes amd64, so absolute figures differ between them —
compare like with like.
