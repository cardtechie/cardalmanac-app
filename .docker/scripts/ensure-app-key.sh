#!/bin/sh
# Ensure the environment carries a usable Laravel APP_KEY.
#
# Sourced (with `.`, never executed) by the local and test entrypoints so the
# export survives into the process they exec.
#
# No APP_KEY literal is committed anywhere in this repository (#430). Production
# receives its key through the GitHub secrets -> cardalmanac.env -> Compose
# substitution path wired up in .github/workflows/deployment.yaml; local and CI
# runs generate an ephemeral one here.

if [ -n "${APP_KEY:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

# A production container must never invent its own key: a fresh key on every
# restart silently invalidates every session, and the failure would surface as
# users being logged out rather than as a missing secret.
if [ "${APP_ENV:-}" = "production" ]; then
    echo "ensure-app-key: APP_KEY is unset or empty and APP_ENV=production; refusing to generate one." >&2
    echo "ensure-app-key: supply it via cardalmanac.env - see .github/workflows/deployment.yaml." >&2
    return 1 2>/dev/null || exit 1
fi

# 32 random bytes, base64-encoded, in the form Laravel's config/app.php expects.
# Deliberately avoids `php artisan key:generate`: this runs before
# `composer dump-autoload` in the test entrypoint, so no Laravel bootstrap is
# available yet, and key:generate would rewrite .env rather than export.
APP_KEY="base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
export APP_KEY
echo "ensure-app-key: generated an ephemeral APP_KEY for APP_ENV=${APP_ENV:-unset}."
