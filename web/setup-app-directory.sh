#!/bin/bash
set -euo pipefail

# Usage: sudo ./setup-app-directory.sh /var/www/myapp [username]
# Prepares an application directory for Laravel/nginx deploys.

APP_PATH="${1:-}"
OWNER="${2:-}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0 /var/www/myapp [username]" >&2
  exit 1
fi

if [[ -z "$APP_PATH" ]]; then
  read -rp "Application directory (e.g. /var/www/myapp): " APP_PATH
fi

if [[ -z "$APP_PATH" || "$APP_PATH" != /* ]]; then
  echo "Application directory must be an absolute path." >&2
  exit 1
fi

if [[ -z "$OWNER" ]]; then
  read -rp "Owner username (deploy user): " OWNER
fi

if [[ -z "$OWNER" ]]; then
  echo "Owner username is required." >&2
  exit 1
fi

if ! id "$OWNER" &>/dev/null; then
  echo "User '$OWNER' does not exist." >&2
  exit 1
fi

if ! getent group www-data &>/dev/null; then
  echo "Group 'www-data' does not exist on this system." >&2
  exit 1
fi

install -d -m 775 -o "$OWNER" -g www-data "$APP_PATH"
chmod -R g+w "$APP_PATH"

cat <<EOF_OUT
============================================================
APP DIRECTORY READY
============================================================
Path:
  ${APP_PATH}
Owner:
  ${OWNER}:www-data
Permissions:
  directories writable by group (g+w)

Use this path as deploy_path in the app's GitHub Actions workflow.
============================================================
EOF_OUT
