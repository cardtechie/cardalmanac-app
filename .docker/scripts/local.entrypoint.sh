#!/bin/sh
set -ex

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

cd /var/www/app

# Export an APP_KEY when none was supplied. No key literal is committed to this
# repository (#430), so local runs generate an ephemeral one here.
. /var/www/app/.docker/scripts/ensure-app-key.sh

# Run the default entrypoint script here - this will check for init/provisioning scripts and run them;
# We do this here to ensure that we are fully provisioned before we continue
/var/www/app/.docker/scripts/entrypoint.sh

/var/www/app/.docker/scripts/wait-for-it.sh mysql:3306 -t 60 --strict -- echo mysql database is ready

#npm run dev

php artisan blog:build

exec "$@"
