#!/bin/bash
set -e

if [ ! -f /var/www/html/bin/console ]; then
    echo "=== Populating volume with SuiteCRM source ==="
    SRC_DIR="/opt/suitecrm-src"
    if [ -f "$SRC_DIR/bin/console" ]; then
        cp -a "$SRC_DIR/." /var/www/html/
    elif [ -d "$SRC_DIR/SuiteCRM-${SUITECRM_VERSION}" ]; then
        cp -a "$SRC_DIR/SuiteCRM-${SUITECRM_VERSION}/." /var/www/html/
    else
        FOUND=$(find "$SRC_DIR" -name "console" -path "*/bin/console" -maxdepth 3 | head -1)
        if [ -n "$FOUND" ]; then
            SUITE_ROOT=$(dirname $(dirname "$FOUND"))
            cp -a "$SUITE_ROOT/." /var/www/html/
        else
            echo "ERROR: Could not find SuiteCRM source files"
            ls -la "$SRC_DIR"/
            exit 1
        fi
    fi
    chown -R www-data:www-data /var/www/html
    echo "=== Volume populated ==="
fi

echo "Waiting for database..."
until mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" &>/dev/null; do
    sleep 2
    echo "  ...waiting for MariaDB at $DB_HOST"
done
echo "Database is ready."

INSTALL_MARKER="/var/www/html/.installed"

if [ ! -f "$INSTALL_MARKER" ]; then
    echo "=== First boot: Installing SuiteCRM ==="

    cd /var/www/html

    cat > .env.local <<EOF
DATABASE_URL="mysql://${DB_USER}:${DB_PASS}@${DB_HOST}:3306/${DB_NAME}"
EOF

    php bin/console suitecrm:app:install \
        -H "$DB_HOST" \
        -Z 3306 \
        -U "$DB_USER" \
        -P "$DB_PASS" \
        -N "$DB_NAME" \
        -S "$SITE_URL" \
        -u "$ADMIN_USER" \
        -p "$ADMIN_PASS" \
        -d yes \
        --no-interaction

    for KEYDIR in public/legacy/Api/V8/OAuth2 Api/V8/OAuth2; do
        mkdir -p "$KEYDIR"
        if [ ! -f "$KEYDIR/private.key" ]; then
            openssl genrsa -out "$KEYDIR/private.key" 2048
            openssl rsa -in "$KEYDIR/private.key" -pubout -out "$KEYDIR/public.key"
        fi
        chown -R www-data:www-data "$KEYDIR"
        chmod 600 "$KEYDIR/private.key"
        chmod 644 "$KEYDIR/public.key"
    done

    chown -R www-data:www-data /var/www/html

    touch "$INSTALL_MARKER"
    echo "=== SuiteCRM installation complete ==="
else
    echo "SuiteCRM already installed, skipping setup."
fi

if [ -n "$OAUTH2_CLIENT_ID" ] && [ -n "$OAUTH2_CLIENT_SECRET" ]; then
    echo "=== Seeding OpenClaw OAuth2 client ==="
    mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<SQL
INSERT INTO oauth2clients (id, name, secret, allowed_grant_type, is_confidential, deleted)
VALUES ('${OAUTH2_CLIENT_ID}', 'openclaw', SHA2('${OAUTH2_CLIENT_SECRET}', 256), 'password', 1, 0)
ON DUPLICATE KEY UPDATE
  secret = SHA2('${OAUTH2_CLIENT_SECRET}', 256),
  allowed_grant_type = 'password',
  is_confidential = 1,
  deleted = 0;
SQL
    echo "OAuth2 client '${OAUTH2_CLIENT_ID}' ready."
fi

echo "* * * * * cd /var/www/html && php bin/console suitecrm:app:cron > /dev/null 2>&1" | crontab -u www-data -
cron

exec "$@"
