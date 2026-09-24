#!/usr/bin/env bash
# Generate the self-signed dev TLS certificates for cardalmanac.dev,
# api.tradingcardapi.dev, and admin.tradingcardapi.dev.
#
# Replaces committing the cert/key/csr artefacts to the repo (#425). Run this
# once after cloning (the `make up` / `upd` / `up-full` / `upd-full` targets
# depend on `certs` and do it automatically) or any time a cert needs
# regenerating -- e.g. after the cardalmanac.dev cert's 2026-10-08 expiry.
#
# Idempotent: an existing <host>.crt + <host>.key pair is left alone unless
# --force is passed. Tested against both macOS LibreSSL and Linux OpenSSL 3.
set -euo pipefail

FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        *)
            echo "generate-dev-certs.sh: unknown argument '$arg' (only --force is supported)" >&2
            exit 1
            ;;
    esac
done

# Resolve the repo root from the script's own path, not the caller's CWD, so
# `make certs` works the same whether invoked from the repo root or anywhere
# else.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# dir:host pairs -- mirrors the docker-compose.yml / docker-compose.full.yml
# bind mounts.
PAIRS=(
    "$REPO_ROOT/.docker/cert:cardalmanac.dev"
    "$REPO_ROOT/.docker/api:api.tradingcardapi.dev"
    "$REPO_ROOT/.docker/admin:admin.tradingcardapi.dev"
)

for pair in "${PAIRS[@]}"; do
    dir="${pair%%:*}"
    host="${pair##*:}"
    crt="$dir/$host.crt"
    key="$dir/$host.key"
    csr="$dir/$host.csr"
    ext="$dir/$host.ext"

    # A bare `docker compose up` with no cert on disk silently creates a
    # DIRECTORY at the bind-mount source path instead of failing loudly.
    # Clear that debris before generating, or openssl's `-out` would fail
    # writing a regular file where a directory now sits.
    for path in "$crt" "$key"; do
        if [ -d "$path" ]; then
            echo "generate-dev-certs.sh: removing directory left by a bare 'docker compose up' at $path"
            rmdir "$path"
        fi
    done

    if [ "$FORCE" -eq 0 ] && [ -f "$crt" ] && [ -f "$key" ]; then
        echo "generate-dev-certs.sh: $host already has a cert/key pair, skipping (use --force to regenerate)"
        continue
    fi

    if [ ! -f "$ext" ]; then
        echo "generate-dev-certs.sh: missing SAN extension file $ext" >&2
        exit 1
    fi

    echo "generate-dev-certs.sh: generating cert for $host"
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout "$key" -out "$csr" \
        -subj "/C=US/ST=Utah/L=St George/O=CardTechie/CN=$host"
    openssl x509 -req -in "$csr" -signkey "$key" -out "$crt" \
        -days 825 -sha256 -extfile "$ext"
    chmod 600 "$key"
done

echo "generate-dev-certs.sh: done"
