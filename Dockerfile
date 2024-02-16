LABEL org.opencontainers.image.source = "https://github.com/mlsh0/oci-arm-docker"
FROM composer:latest AS composer
FROM php:8.3-alpine3.19
COPY --from=composer /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY app/ .
RUN apk update && apk add --no-cache libxml2-dev libzip-dev libcurl curl-dev
RUN docker-php-ext-install xml zip curl phar dom
RUN composer install
CMD [ "php", "index.php" ]
