FROM php:7.4-fpm-alpine as base

RUN apk --no-cache add --virtual .project-deps \
    freetype libjpeg-turbo libpng libxpm \
    icu-libs \
    libzip \
    libpq \
    git \
    tzdata

RUN apk --no-cache add --virtual .build-deps \
    freetype-dev libjpeg-turbo-dev libpng-dev libxpm-dev \
    icu-dev \
    cmake gnutls-dev libzip-dev libressl-dev zlib-dev \
    libxml2-dev \
    postgresql-dev \
    autoconf build-base && \
    docker-php-ext-configure pgsql --with-pgsql=/usr/local/pgsql && \ 
    docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ && \
    docker-php-ext-install -j$(getconf _NPROCESSORS_ONLN) iconv intl pdo pdo_pgsql zip soap exif gd && \
    pecl install xdebug && \
    pecl install apcu && \
    docker-php-ext-enable apcu && \
    docker-php-ext-enable opcache && \
    apk del --purge .build-deps

RUN mkdir /var/cache/symfony && \
    chown www-data:www-data /var/cache/symfony && \
    mkdir /var/log/symfony && \
    chown www-data:www-data /var/log/symfony

RUN ln -s $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini

FROM base as development
RUN docker-php-ext-enable xdebug
ENV COMPOSER_ALLOW_SUPERUSER 1
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN set -eux; \
	composer global require "symfony/flex" --prefer-dist --no-progress --no-suggest --classmap-authoritative; \
	composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"
COPY docker/php/conf.d/symfony.dev.ini $PHP_INI_DIR/conf.d/symfony.ini

FROM development as ci
COPY . /var/www/html
RUN composer install

FROM base as vendor
COPY . /var/www/html
ENV COMPOSER_ALLOW_SUPERUSER 1
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN set -eux; \
	composer global require "symfony/flex" --prefer-dist --no-progress --no-suggest --classmap-authoritative; \
	composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"
RUN /usr/bin/composer install --no-ansi --no-dev --no-interaction --no-progress --classmap-authoritative

FROM base as production
COPY --from=vendor /var/www/html /var/www/html
COPY docker/php/conf.d/symfony.prod.ini $PHP_INI_DIR/conf.d/symfony.ini