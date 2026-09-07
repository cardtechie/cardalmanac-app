#!/bin/sh
set -ex

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

cd /var/www/app

# Export an APP_KEY when none was supplied. No key literal is committed to this
# repository (#430), so CI runs generate an ephemeral one here.
. /var/www/app/.docker/scripts/ensure-app-key.sh

# refresh libraries now that our code is bind-mounted in place
composer dump-autoload

# run default entrypoint
#/var/www/app/.docker/scripts/entrypoint.sh

exec "$@"
