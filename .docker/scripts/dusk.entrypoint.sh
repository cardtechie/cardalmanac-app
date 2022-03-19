#!/bin/sh
set -ex

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

cd /var/www/app

# Run the default entrypoint script here - this will check for init/provisioning scripts and run them;
# We do this here to ensure that we are fully provisioned before we continue
/var/www/app/.docker/scripts/entrypoint.sh

# Refresh autoloaders, run migrations, etc.
composer dump-autoload

DUSK_DIRS="
  storage/dusk/storage/app/public \
  storage/dusk/storage/framework/cache/data \
  storage/dusk/storage/framework/sessions \
  storage/dusk/storage/framework/views \
  storage/dusk/storage/logs \
  storage/dusk/bootstrap/cache
"

mkdir -p ${DUSK_DIRS}
chown -R www-data ${DUSK_DIRS}
chmod -R 775 ${DUSK_DIRS}

if [ "${DB_CONNECTION}" = "sqlite" ]; then
  rm -fv ${DB_DATABASE}
  touch ${DB_DATABASE}
  chown -R www-data: storage
else
  /var/www/app/.docker/scripts/wait-for-it.sh mysql:3306 -t 60 --strict -- echo "mysql database is ready"
fi

php artisan migrate --database=mysql

exec "$@"
