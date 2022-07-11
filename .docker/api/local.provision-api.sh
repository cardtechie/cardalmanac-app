#!/bin/sh
set -ex

cd /var/www/app/

if [ ! -f /var/www/app/storage/oauth-public.key ]; then
  # Generate oauth keys
  php artisan passport:keys
fi

/var/www/app/.docker/scripts/wait-for-it.sh mysql:3306 -t 60 --strict -- echo mysql database is ready
php artisan migrate
