FROM composer:2 AS composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts
COPY . ./
RUN composer dump-autoload --optimize --no-scripts

FROM node:20-alpine AS assets
WORKDIR /app
COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./
RUN if [ -f package-lock.json ]; then npm ci; elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; elif [ -f pnpm-lock.yaml ]; then npm i -g pnpm && pnpm i --frozen-lockfile; else npm install; fi
COPY . ./
RUN if [ -f package.json ]; then npm run build; fi

FROM php:8.2-apache
WORKDIR /var/www/html
RUN apt-get update && apt-get install -y git unzip libpng-dev libjpeg62-turbo-dev libfreetype6-dev libzip-dev libsqlite3-dev libonig-dev && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && docker-php-ext-install pdo_mysql pdo_sqlite bcmath exif mbstring gd zip
RUN a2enmod rewrite
COPY --from=composer /usr/bin/composer /usr/bin/composer
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/default-ssl.conf && printf '%s\n' '<Directory "/var/www/html/public">' 'AllowOverride All' '</Directory>' > /etc/apache2/conf-available/laravel.conf && a2enconf laravel
COPY --chown=www-data:www-data . .
COPY --chown=www-data:www-data --from=composer /app/vendor ./vendor
COPY --from=assets /app/public/build ./public/build
RUN chown -R www-data:www-data storage bootstrap/cache && chmod -R 775 storage bootstrap/cache
