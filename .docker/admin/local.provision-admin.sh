#!/bin/sh
set -ex

cd /var/www/app

/var/www/app/.docker/scripts/wait-for-it.sh -t 0 mysql:3306
# Setup the directory structure
/var/www/app/.docker/scripts/laravel.sh
# Wait for the api to boot to avoid database errors
/var/www/app/.docker/scripts/wait-for-it.sh -t 0 tcapi:443
