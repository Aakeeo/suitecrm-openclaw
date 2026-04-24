FROM php:8.2-apache-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV SUITECRM_VERSION=8.9.2

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev libxml2-dev \
    libzip-dev libicu-dev libldap2-dev libkrb5-dev \
    libonig-dev libcurl4-openssl-dev libssl-dev \
    unzip wget cron mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions (skip imap - optional, needs libc-client)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        intl gd mbstring mysqli pdo_mysql soap zip \
        curl xml opcache bcmath ldap \
    && pecl install redis && docker-php-ext-enable redis

# Enable Apache modules
RUN a2enmod rewrite headers expires

# Change Apache listen port to 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

# Download SuiteCRM 8.9.2 to a staging area
RUN cd /tmp \
    && wget -q "https://github.com/salesagility/SuiteCRM-Core/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip" \
    && mkdir -p /opt/suitecrm-src \
    && unzip -q "SuiteCRM-${SUITECRM_VERSION}.zip" -d /opt/suitecrm-src \
    && rm "SuiteCRM-${SUITECRM_VERSION}.zip"

# Copy Apache vhost config
COPY config/apache-vhost.conf /etc/apache2/sites-available/000-default.conf

# Copy PHP config
COPY config/php.ini /usr/local/etc/php/conf.d/suitecrm.ini

# Copy entrypoint
COPY suitecrm/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
