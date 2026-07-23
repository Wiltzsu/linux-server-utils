#!/bin/bash
set -euo pipefail

# Usage: sudo ./setup-fastcgi-cache.sh /etc/nginx/sites-available/example.conf
# Enables nginx FastCGI cache for WordPress/Bedrock PHP sites.

SITE_CONFIG="${1:-}"
CACHE_PATH="/var/cache/nginx/fastcgi"
CACHE_ZONE="WORDPRESS"
CACHE_PATH_CONF="/etc/nginx/conf.d/fastcgi-cache-path.conf"
CACHE_SNIPPET="/etc/nginx/snippets/fastcgi-cache-wordpress.conf"
CACHE_INCLUDE_MARKER="# fastcgi-cache (setup-fastcgi-cache.sh)"

# Defaults (override with env vars)
CACHE_KEYS_SIZE="${CACHE_KEYS_SIZE:-100m}"
CACHE_MAX_SIZE="${CACHE_MAX_SIZE:-1g}"
CACHE_INACTIVE="${CACHE_INACTIVE:-60m}"
CACHE_VALID="${CACHE_VALID:-60m}"

usage() {
  cat <<EOF
Usage: sudo $0 /etc/nginx/sites-available/example.conf

Optional environment variables:
  CACHE_KEYS_SIZE   keys_zone size (default: 100m)
  CACHE_MAX_SIZE    on-disk max size (default: 1g)
  CACHE_INACTIVE    purge inactive entries after (default: 60m)
  CACHE_VALID       cache 200 responses for (default: 60m)

Example:
  sudo CACHE_VALID=30m $0 /etc/nginx/sites-available/mydevsite.conf
EOF
}

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0 /etc/nginx/sites-available/example.conf" >&2
  exit 1
fi

if [[ -z "$SITE_CONFIG" ]]; then
  usage >&2
  exit 1
fi

if [[ ! -f "$SITE_CONFIG" ]]; then
  echo "Site config not found: $SITE_CONFIG" >&2
  exit 1
fi

if ! command -v nginx &>/dev/null; then
  echo "nginx is not installed." >&2
  exit 1
fi

if ! grep -q 'location ~ \\.php\$' "$SITE_CONFIG"; then
  echo "No PHP location block found in $SITE_CONFIG" >&2
  echo "Expected: location ~ \\.php\$ { ... }" >&2
  exit 1
fi

install -d -m 755 "$CACHE_PATH"
chown www-data:www-data "$CACHE_PATH"

cat >"$CACHE_PATH_CONF" <<EOF
# Managed by linux-server-utils setup-fastcgi-cache.sh
fastcgi_cache_path ${CACHE_PATH} levels=1:2 keys_zone=${CACHE_ZONE}:${CACHE_KEYS_SIZE} inactive=${CACHE_INACTIVE} max_size=${CACHE_MAX_SIZE};
fastcgi_cache_key "\$scheme\$request_method\$host\$request_uri";
EOF

cat >"$CACHE_SNIPPET" <<EOF
# Managed by linux-server-utils setup-fastcgi-cache.sh
${CACHE_INCLUDE_MARKER}

set \$skip_cache 0;

if (\$request_method = POST) {
    set \$skip_cache 1;
}

if (\$query_string != "") {
    set \$skip_cache 1;
}

if (\$request_uri ~* "/wp-admin/|/wp-login\\.php|/wp-json/|/xmlrpc\\.php|/feed/|/index\\.php|sitemap(_index)?\\.xml") {
    set \$skip_cache 1;
}

if (\$http_cookie ~* "comment_author|wordpress_[a-f0-9]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") {
    set \$skip_cache 1;
}

fastcgi_cache ${CACHE_ZONE};
fastcgi_cache_valid 200 ${CACHE_VALID};
fastcgi_cache_bypass \$skip_cache;
fastcgi_no_cache \$skip_cache;
fastcgi_cache_use_stale error timeout invalid_header updating http_500 http_503;
fastcgi_cache_background_update on;
fastcgi_cache_lock on;

add_header X-FastCGI-Cache \$upstream_cache_status always;
EOF

if grep -qF "$CACHE_INCLUDE_MARKER" "$SITE_CONFIG"; then
  echo "Site config already includes FastCGI cache snippet."
else
  tmp="$(mktemp)"
  awk -v marker="$CACHE_INCLUDE_MARKER" '
    /location ~ \\.php\$ \{/ { in_php=1 }
    in_php && /fastcgi_pass/ && !added {
      print
      print "        include snippets/fastcgi-cache-wordpress.conf;  " marker
      added=1
      next
    }
    { print }
  ' "$SITE_CONFIG" >"$tmp"
  mv "$tmp" "$SITE_CONFIG"
  echo "Added FastCGI cache include to $SITE_CONFIG"
fi

nginx -t

if systemctl is-active --quiet nginx; then
  systemctl reload nginx
  echo "nginx reloaded."
else
  echo "nginx config OK. Start nginx when ready: systemctl start nginx"
fi

cat <<EOF_OUT

============================================================
FASTCGI CACHE ENABLED
============================================================
Cache path:
  ${CACHE_PATH}
Zone:
  ${CACHE_ZONE}
Site config:
  ${SITE_CONFIG}

Verify (anonymous GET, no query string):
  curl -sI https://your-domain/ | grep -i x-fastcgi-cache

Expected values: MISS (first hit), HIT (cached), BYPASS (logged-in/admin)

Purge all cached pages:
  sudo rm -rf ${CACHE_PATH}/*
  sudo systemctl reload nginx
============================================================
EOF_OUT
