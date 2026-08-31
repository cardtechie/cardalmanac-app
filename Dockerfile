# syntax=docker/dockerfile:1.7
#
# Multi-stage build. See docs/DOCKER-IMAGE.md for the stage graph and for which
# target each consumer builds.
#
#   base    -> everything both dev and runtime need at run time
#   assets  -> compiles the front-end bundle (Node lives here and nowhere else)
#   vendor  -> production-only Composer dependencies + optimized autoloader
#   dev     -> local development and CI: full toolchain, Xdebug, dev deps
#   runtime -> what ships to production; LAST stage, so an untargeted build
#              produces the slim image rather than the fat one
#
# COMPOSER_TOKEN is passed as a BuildKit secret, never as a build ARG: `docker
# history` renders ARG values in plaintext, so an ARG puts the credential in the
# published image's layer metadata.

##############################################################################
# base
##############################################################################
FROM php:8.2-fpm AS base

ENV MIX_APP_URL="https://cardalmanac.com"

# PHP / FPM config defaults that we set via environment variables
ENV PHP_OPCACHE_ENABLE=0 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=64 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=2000 \
    PHP_OPCACHE_REVALIDATE_FREQ=2 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_INTERNED_STRINGS_BUFFER=4 \
    PHP_OPCACHE_FAST_SHUTDOWN=0 \
    PHP_OPCACHE_BLACKLIST_FILENAME="" \
    PHP_UPLOAD_MAX_FILESIZE=5G \
    PHP_POST_MAX_SIZE=5G \
    PHP_LOG_ERRORS=On \
    PHP_ERROR_LOG=/dev/stderr \
    PHP_SHORT_OPEN_TAG=On \
    FASTCGI_READ_TIMEOUT=60s \
    FPM_PM=dynamic \
    FPM_PM_MAX_CHILDREN=50 \
    FPM_PM_START_SERVERS=4 \
    FPM_PM_MIN_SPARE_SERVERS=4 \
    FPM_PM_MAX_SPARE_SERVERS=8

ENV PATH="/composer/vendor/bin:/var/www/app/vendor/bin:/var/www/app/node_modules/.bin:$PATH"

# PHP extensions. The -dev headers exist only so docker-php-ext-install can
# compile, so they are installed and purged inside this single RUN -- nothing
# that only exists to build survives into the layer. The apt-mark/ldd dance is
# the php image's documented recipe: it re-marks the runtime shared libraries
# the freshly built extensions link against as manually installed, so
# `apt-get purge --auto-remove` cannot take them along with the headers.
#
# The `readlink -f` is load-bearing: ldd reports these libraries under /lib/...,
# but on a usrmerged Debian dpkg records them under /usr/lib/... and
# `dpkg-query --search` no longer resolves the alias. Without canonicalizing,
# every lookup misses, nothing gets re-marked manual, and the purge silently
# takes libzip5 with it -- leaving a zip.so in the image that cannot load.
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libzip-dev; \
    docker-php-ext-configure opcache --enable-opcache; \
    docker-php-ext-install -j"$(nproc)" \
        opcache \
        pdo \
        pdo_mysql \
        zip; \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | grep '^/' \
        | sort -u \
        | xargs -r readlink -f \
        | sort -u \
        | xargs -r dpkg-query --search 2>/dev/null \
        | cut -d: -f1 \
        | sort -u \
        | xargs -r apt-mark manual > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    php -m | grep -q '^zip$'; \
    php -m | grep -q '^pdo_mysql$'; \
    php -m | grep -qi 'OPcache'

# Runtime packages only. certbot stays: renew-certificate.yaml runs
# `docker exec <container> certbot renew` against the running production
# container and .docker/prod.docker-compose.yaml mounts /etc/letsencrypt into
# it, so removing certbot would break TLS renewal outright.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        ca-certificates \
        certbot \
        curl \
        libfcgi0ldbl \
        nginx \
        openssl \
        python3-certbot-nginx \
        supervisor; \
    rm -rf /var/lib/apt/lists/*; \
    ln -sf /dev/stdout /var/log/nginx/access.log; \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY ./.docker/config/php.app.ini /usr/local/etc/php/conf.d/app.ini
COPY ./.docker/config/local.phpfpm-app.conf /usr/local/etc/php-fpm.d/zzz-app.conf
COPY ./.docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
#COPY ./.docker/config/laravel-worker.supervisord.conf /etc/supervisor/conf.d/laravel-worker.conf
COPY ./.docker/config/nginx.conf /etc/nginx/nginx.conf
COPY ./.docker/config/nginx-laravel.conf /etc/nginx/conf.d/server/nginx-laravel.conf
COPY ./.docker/config/nginx-status.conf /etc/nginx/conf.d/server/nginx-status.conf
COPY ./.docker/config/nginx-site-prod.conf /etc/nginx/conf.d/default.conf

WORKDIR /var/www/app

##############################################################################
# assets
##############################################################################
FROM node:20-bookworm-slim AS assets

# webpack.mix.js bakes MIX_* values in at compile time, so this has to match the
# value the old single-stage build compiled with.
ENV MIX_APP_URL="https://cardalmanac.com" \
    NPM_CONFIG_LOGLEVEL=info

WORKDIR /app

# Deliberately no NODE_ENV=production: the whole build toolchain (laravel-mix,
# sass, tailwindcss, postcss) lives in devDependencies, so a production-only
# install would leave nothing to build with.
#
# `npm install`, not `npm ci`: the committed package-lock.json is currently out
# of sync with package.json (npm ci fails with "Missing: yaml@2.9.0 from lock
# file"). Re-syncing the lockfile changes dependency resolution and belongs in
# its own change; this keeps the single-stage build's existing behaviour.
COPY package.json package-lock.json ./
RUN npm install

# Exactly the inputs webpack.mix.js and tailwind.config.js read.
COPY webpack.mix.js tailwind.config.js ./
COPY resources ./resources
COPY app ./app
COPY public ./public

RUN npm run production

##############################################################################
# vendor
##############################################################################
FROM base AS vendor

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/composer \
    COMPOSER_VENDOR_DIR=/var/www/app/vendor

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        git \
        unzip; \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/app

COPY ./composer.json ./composer.lock ./

# The token is mounted for the duration of this RUN only and is never written to
# a layer; the auth.json composer derives from it is removed in the same step.
# An empty or absent secret is fine -- both VCS repositories are public, so an
# unauthenticated install only risks anonymous GitHub API rate limits.
RUN --mount=type=secret,id=composer_token set -eux; \
    if [ -s /run/secrets/composer_token ]; then \
        composer config --global github-oauth.github.com "$(cat /run/secrets/composer_token)"; \
    fi; \
    composer install --no-dev --no-scripts --no-autoloader --no-interaction --prefer-dist --ansi; \
    rm -f "${COMPOSER_HOME}/auth.json"

# Application code, then the optimized production autoloader. dump-autoload runs
# here rather than in `runtime` because post-autoload-dump invokes
# `php artisan package:discover`, which writes bootstrap/cache -- so vendor/ and
# bootstrap/cache/ both leave this stage as finished artifacts.
COPY . .
RUN composer dump-autoload -o --no-dev --ansi

##############################################################################
# dev
##############################################################################
FROM base AS dev

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_VENDOR_DIR=/var/www/vendor \
    COMPOSER_HOME=/composer \
    NPM_CONFIG_LOGLEVEL=info \
    NODE_ENV=development \
    NODE_PATH=/var/www/node_modules

# XDEBUG Settings
ENV XDEBUG_ENABLED=0 \
    XDEBUG_AUTOSTART=off \
    XDEBUG_CONF_FILE=docker-php-ext-xdebug.ini \
    XDEBUG_CONNECT_BACK_PORT=9000 \
    XDEBUG_CONNECT_BACK=0 \
    XDEBUG_REMOTE_HOST=localhost \
    XDEBUG_REMOTE_LOG=/var/www/app/storage/logs/xdebug.log

RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    dirmngr \
    dos2unix \
    git \
    g++ \
    jq \
    libedit-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libnss3-dev \
    libmcrypt-dev \
    libpq-dev \
    libreadline-dev \
    libssl-dev \
    libzip-dev \
    openssh-client \
    rsync \
    sqlite3 \
    unzip \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/*

#
# XDEBUG INSTALL
#
# install xdebug, setup environment variables, and create xdebug enablement script
RUN docker-php-source extract \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && docker-php-source delete \
    && mkdir -p "${PHP_INI_DIR}/../mods-available" \
    && mv "${PHP_INI_DIR}/conf.d/${XDEBUG_CONF_FILE}" "${PHP_INI_DIR}/../mods-available" \
    && { \
        echo ""; \
        echo "[xdebug]"; \
        echo "xdebug.remote_enable = ${XDEBUG_ENABLED}"; \
        echo "xdebug.remote_autostart = ${XDEBUG_AUTOSTART}"; \
        echo "xdebug.remote_connect_back = ${XDEBUG_CONNECT_BACK}"; \
        echo "xdebug.remote_host = ${XDEBUG_REMOTE_HOST}"; \
        echo "xdebug.remote_port = ${XDEBUG_CONNECT_BACK_PORT}"; \
        echo "xdebug.remote_log = ${XDEBUG_REMOTE_LOG}"; \
        echo "xdebug.remote_handler = dbgp"; \
        echo "xdebug.max_nesting_level = 1000"; \
    } >> "${PHP_INI_DIR}/../mods-available/${XDEBUG_CONF_FILE}"

# Copy the Composer PHAR from the Composer image into our image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy node into our image. Node 16 went end-of-life in September 2023; 20 is the
# LTS release laravel-mix 6 / webpack 5 build cleanly on.
COPY --from=node:20-bookworm-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:20-bookworm-slim /usr/local/lib/node_modules /usr/local/lib/node_modules

# Link node/npm onto PATH, and add bitbucket and github to known hosts for ssh needs
RUN set -eux; \
    ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
    ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm; \
    mkdir -p /root/.ssh; \
    chmod 0600 /root/.ssh; \
    ssh-keyscan -t rsa bitbucket.org >> /root/.ssh/known_hosts; \
    ssh-keyscan -t rsa github.com >> /root/.ssh/known_hosts

# Install composer packages -- WITH dev dependencies, because CI runs
# `npm test` (prettier + vendor/bin/parallel-lint) and phpunit out of this image.
WORKDIR /var/www/app
COPY --chown=www-data:www-data ./composer.json ./composer.lock ./
RUN --mount=type=secret,id=composer_token set -eux; \
    if [ -s /run/secrets/composer_token ]; then \
        composer config --global github-oauth.github.com "$(cat /run/secrets/composer_token)"; \
    fi; \
    composer install --no-scripts --no-autoloader --ansi --no-interaction; \
    rm -f "${COMPOSER_HOME}/auth.json"

WORKDIR /var/www
COPY --chown=www-data:www-data ./package.json ./package-lock.json ./
RUN npm install

ENV COMPOSER_VENDOR_DIR=/var/www/app/vendor \
    NODE_PATH=/var/www/app/node_modules

# Copy in app code as late as possible, as it changes the most
WORKDIR /var/www/app
COPY --chown=www-data:www-data . .

# Create symlinks into /var/www/app. We do this so the image has these available in the app directory,
# but also to ensure that when we bind-mount code in a dev enviroment these directories are still available
# to copy into the local dev environment
RUN ln -s /var/www/vendor /var/www/app/vendor \
    && ln -s /var/www/node_modules /var/www/app/node_modules

RUN composer dump-autoload -o
RUN npm run production

# Copy the .env.local as the base for environment variables within the image. Dev systems will bind-mount on top of
# this and instead pass the environment values into the container environment through the compose env_file values.
# But we still need this here for other environments so we have a reasonable set of default values specified for the
# application layer through the container's environment vars.
RUN cp .env.local .env

# Run entrypoint
RUN chmod 775 ./.docker/scripts/*.sh
ENTRYPOINT ["/var/www/app/.docker/scripts/entrypoint.sh"]

EXPOSE 80 443 9001

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

##############################################################################
# runtime -- MUST remain the last stage in this file
##############################################################################
FROM base AS runtime

WORKDIR /var/www/app

# Application code first, then the built artifacts on top of it. public/js,
# public/css and public/webfonts are gitignored, so the compiled bundle can only
# come from the assets stage.
COPY --chown=www-data:www-data . .
COPY --from=vendor --chown=www-data:www-data /var/www/app/vendor ./vendor
COPY --from=vendor --chown=www-data:www-data /var/www/app/bootstrap/cache ./bootstrap/cache
COPY --from=assets --chown=www-data:www-data /app/public/js ./public/js
COPY --from=assets --chown=www-data:www-data /app/public/css ./public/css
COPY --from=assets --chown=www-data:www-data /app/public/webfonts ./public/webfonts
COPY --from=assets --chown=www-data:www-data /app/public/mix-manifest.json ./public/mix-manifest.json

# Copy the .env.local as the base for environment variables within the image, so
# there is a reasonable set of defaults for the application layer even before the
# deployment's own environment is layered on top.
RUN cp .env.local .env \
    && chmod 775 ./.docker/scripts/*.sh

ENTRYPOINT ["/var/www/app/.docker/scripts/entrypoint.sh"]

EXPOSE 80 443 9001

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
