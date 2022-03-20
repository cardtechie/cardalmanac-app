#!/bin/sh
set -ex

cd /var/www/app

timeout 180 bash -c "\
    until mysql \
    -h ${WP_DB_HOST} \
    -u ${WP_DB_USER} \
    --password=\"${WP_DB_PASSWORD}\" \
    -e 'CREATE SCHEMA IF NOT EXISTS \`${WP_DB_NAME}\`'; \
    do sleep 5; done
    " >/dev/null 2>&1
