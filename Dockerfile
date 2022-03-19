FROM php:8.1-fpm AS build

ENV NGINX_VERSION=1.15.5-1~stretch \
    NJS_VERSION=1.15.5.0.2.4-1~stretch

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
    FPM_PM=dynamic \
    FPM_PM_MAX_CHILDREN=50 \
    FPM_PM_START_SERVERS=4 \
    FPM_PM_MIN_SPARE_SERVERS=4 \
    FPM_PM_MAX_SPARE_SERVERS=8

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
    XDEBUG_REMOTE_LOG=/var/www/app/storage/logs/xdebug.log \
    FASTCGI_READ_TIMEOUT=60s

RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    ca-certificates \
    curl \
    dirmngr \
    dos2unix \
    git \
    g++ \
    jq \
    libedit-dev \
    libfcgi0ldbl \
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
    openssl \
    rsync \
    sqlite3 \
    supervisor \
    unzip \
    wget \
    zip \
    && rm -rf /var/lib/apt/lists/*

#RUN apt-get -y install chromium-browser xvfb gtk2-engines-pixbuf xfonts-cyrillic xfonts-100dpi xfonts-75dpi xfonts-base xfonts-scalable imagemagick x11-apps
RUN docker-php-ext-configure opcache --enable-opcache

# Install extensions using the helper script provided by the base image
RUN docker-php-ext-install \
    opcache \
    pdo \
    pdo_mysql \
#    readline \
    zip

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

# Install nginx (copied from official nginx Dockerfile 1.15.5)
RUN set -x \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 apt-transport-https ca-certificates \
    && \
    NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
    found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
        apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION} \
        nginx-module-xslt=${NGINX_VERSION} \
        nginx-module-geoip=${NGINX_VERSION} \
        nginx-module-image-filter=${NGINX_VERSION} \
        nginx-module-njs=${NJS_VERSION} \
    " \
    && case "$dpkgArch" in \
        amd64|i386) \
# arches officialy built by upstream
            echo "deb https://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list \
            && apt-get update \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published source packages
            echo "deb-src https://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list.d/nginx.list \
            \
# new directory for storing sources and .deb files
            && tempDir="$(mktemp -d)" \
            && chmod 777 "$tempDir" \
# (777 to ensure APT's "_apt" user can access it too)
            \
# save list of currently-installed packages so build dependencies can be cleanly removed later
            && savedAptMark="$(apt-mark showmanual)" \
            \
# build .deb files from upstream's source packages (which are verified by apt-get)
            && apt-get update \
            && apt-get build-dep -y $nginxPackages \
            && ( \
                cd "$tempDir" \
                && DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" \
                    apt-get source --compile $nginxPackages \
            ) \
# we don't remove APT lists here because they get re-downloaded and removed later
            \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
            && apt-mark showmanual | xargs apt-mark auto > /dev/null \
            && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
            \
# create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
            && ls -lAFh "$tempDir" \
            && ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
            && grep '^Package: ' "$tempDir/Packages" \
            && echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
# work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
#   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
#   ...
#   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
            && apt-get -o Acquire::GzipIndexes=false update \
            ;; \
    esac \
    \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        $nginxPackages \
                        gettext-base \
    && apt-get remove --purge --auto-remove -y apt-transport-https && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then \
        apt-get purge -y --auto-remove \
        && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi

RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    certbot \
    python3-certbot-nginx \
    && rm -rf /var/lib/apt/lists/*

# Forward nginx request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Copy the Composer PHAR from the Composer image into our image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Copy node into our image
COPY --from=node:16 /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/bin/node /usr/local/bin/nodejs
COPY --from=node:16 /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# Copy mysqldump into our image
COPY --from=mysql:8.0 /usr/bin/mysqldump /usr/bin/mysqldump
COPY --from=mysql:8.0 /usr/bin/mysql /usr/bin/mysql

# add bitbucket and github to known hosts for ssh needs
WORKDIR /root/.ssh
RUN chmod 0600 /root/.ssh \
    && ssh-keyscan -t rsa bitbucket.org >> known_hosts \
    && ssh-keyscan -t rsa github.com >> known_hosts

ENV PATH="/composer/vendor/bin:/var/www/app/vendor/bin:/var/www/app/node_modules/.bin:$PATH"

# Install composer packages
WORKDIR /var/www/app
#COPY --chown=www-data:www-data ./composer.json ./composer.lock ./
#RUN composer config github-oauth.github.com 3126a3ccf2873a0af021d0d1776434eb21e71ed4
#RUN composer install --no-scripts --no-autoloader --ansi --no-interaction

#WORKDIR /var/www
#COPY --chown=www-data:www-data ./package.json ./package-lock.json ./
#RUN npm install

#ENV COMPOSER_VENDOR_DIR=/var/www/app/vendor \
#    NODE_PATH=/var/www/app/node_modules

WORKDIR /var/www/app
COPY ./.docker/config/php.app.ini /usr/local/etc/php/conf.d/app.ini
COPY ./.docker/config/local.phpfpm-app.conf /usr/local/etc/php-fpm.d/zzz-app.conf
COPY ./.docker/config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
#COPY ./.docker/config/laravel-worker.supervisord.conf /etc/supervisor/conf.d/laravel-worker.conf
#COPY ./.docker/config/nginx.conf /etc/nginx/nginx.conf
#COPY ./.docker/config/nginx-laravel.conf /etc/nginx/conf.d/server/nginx-laravel.conf
#COPY ./.docker/config/nginx-status.conf /etc/nginx/conf.d/server/nginx-status.conf
#COPY ./.docker/config/nginx-site-prod.conf /etc/nginx/conf.d/default.conf

# Copy in app code as late as possible, as it changes the most
COPY --chown=www-data:www-data . .

# Create symlinks into /var/www/app. We do this so the image has these available in the app directory,
# but also to ensure that when we bind-mount code in a dev enviroment these directories are still available
# to copy into the local dev environment
#RUN ln -s /var/www/vendor /var/www/app/vendor \
#    && ln -s /var/www/node_modules /var/www/app/node_modules

# Copy the .env.local as the base for environment variables within the image. Dev systems will bind-mount on top of
# this and instead pass the environment values into the container environment through the compose env_file values.
# But we still need this here for other environments so we have a reasonable set of default values specified for the
# application layer through the container's environment vars.
RUN cp .env.local .env

#RUN composer dump-autoload -o
#RUN php artisan ziggy:generate --url=${APP_URL}
#RUN npm run build

# Run entrypoint
RUN chmod 775 ./.docker/scripts/*.sh
ENTRYPOINT ["/var/www/app/.docker/scripts/entrypoint.sh"]

EXPOSE 80 443 9001

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
