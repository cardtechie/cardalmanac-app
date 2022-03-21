#!/bin/sh
set -ex

cd /var/www/app

# Create the schema
timeout 180 bash -c "\
    until mysql \
    -h ${WP_DB_HOST} \
    -u ${WP_DB_USER} \
    --password=\"${WP_DB_PASSWORD}\" \
    -e 'CREATE SCHEMA IF NOT EXISTS \`${WP_DB_NAME}\`'; \
    do sleep 5; done
    " >/dev/null 2>&1

# Cleanup
CONFIG_SAMPLE=/var/www/app/public/blog/wordpress/wp-config-sample.php
if [ -f ${CONFIG_SAMPLE} ]; then
    rm ${CONFIG_SAMPLE}
fi

# Remove default content directory
ORIGINAL_CONTENT=/var/www/app/public/blog/wordpress/wp-content
if [ -d ${ORIGINAL_CONTENT} ]; then
    rm -rf ${ORIGINAL_CONTENT}
fi
