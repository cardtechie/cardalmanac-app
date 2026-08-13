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

# Setup the laravel directory structure
/var/www/app/.docker/scripts/laravel.sh

# These are commands run INSIDE of the container after an update is deployed
# These commands will run for EVERY code update
#php artisan migrate
#php artisan queue:restart
#php artisan view:cache

#npm run production

# The container deliberately does not touch certbot at startup (#407).
# Certificates persist on the /etc/letsencrypt volume mount, so one is already
# on disk at every restart, and renewal is handled out-of-band by the twice-daily
# .github/workflows/renew-certificate.yaml (#404), which renews against the
# running nginx with no downtime.
#
# Calling install-cert.sh here was pure liability: `certbot renew` sleeps up to
# ~8 minutes of jitter before this script reaches `exec "$@"` (the line that
# starts nginx), and under `set -e` any certbot failure -- Let's Encrypt outage,
# rate limit, network blip -- aborted the entrypoint outright, so the container
# never came up at all.
#
# install-cert.sh is unchanged and still run by hand for first issuance on a new
# host. See docs/TLS-CERTIFICATES.md.

php artisan blog:build

exec "$@"
