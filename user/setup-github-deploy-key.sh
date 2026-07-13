#!/bin/bash
set -euo pipefail

# Usage:
#   sudo ./setup-github-deploy-key.sh william
# Or, logged in as the deploy user:
#   ./setup-github-deploy-key.sh
#
# Creates a passphrase-free SSH key for GitHub Actions deploys and installs
# the public key in authorized_keys. This is separate from create-user.sh,
# which generates a passphrase-protected key for laptop login.

KEY_NAME="github_actions_deploy"
KEY_COMMENT="github-actions-deploy"

resolve_target_user() {
  local requested="${1:-}"

  if [[ -n "$requested" ]]; then
    if [[ $EUID -ne 0 ]]; then
      echo "Run as root to create a key for another user: sudo $0 $requested" >&2
      exit 1
    fi
    if ! id "$requested" &>/dev/null; then
      echo "User '$requested' does not exist." >&2
      exit 1
    fi
    printf '%s' "$requested"
    return
  fi

  if [[ $EUID -eq 0 ]]; then
    echo "Run as root with a username, or run as the deploy user without arguments." >&2
    echo "Example: sudo $0 william" >&2
    exit 1
  fi

  whoami
}

TARGET_USER="$(resolve_target_user "${1:-}")"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
SSH_DIR="$USER_HOME/.ssh"
PRIVATE_KEY="$SSH_DIR/$KEY_NAME"
PUBLIC_KEY="$PRIVATE_KEY.pub"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
SERVER_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
if [[ -z "$SERVER_IP" ]]; then
  SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
if [[ -z "$SERVER_IP" ]]; then
  SERVER_IP="$HOSTNAME_FQDN"
fi

run_as_target() {
  if [[ "$(whoami)" == "$TARGET_USER" ]]; then
    bash -c "$1"
  else
    sudo -u "$TARGET_USER" bash -c "$1"
  fi
}

if [[ -f "$PRIVATE_KEY" ]]; then
  echo "Deploy key already exists: $PRIVATE_KEY" >&2
  echo "Delete it first if you need a new key." >&2
  exit 1
fi

run_as_target "install -d -m 700 '$SSH_DIR'"

if ! run_as_target "ssh-keygen -t ed25519 -f '$PRIVATE_KEY' -N '' -C '${KEY_COMMENT}@${HOSTNAME_FQDN}'"; then
  echo "Failed to generate deploy key." >&2
  exit 1
fi

PUB_KEY_CONTENT="$(cat "$PUBLIC_KEY")"
if ! run_as_target "touch '$AUTHORIZED_KEYS' && chmod 600 '$AUTHORIZED_KEYS'"; then
  echo "Failed to prepare authorized_keys." >&2
  exit 1
fi

if ! grep -qxF "$PUB_KEY_CONTENT" "$AUTHORIZED_KEYS" 2>/dev/null; then
  if [[ "$(whoami)" == "$TARGET_USER" ]]; then
    printf '%s\n' "$PUB_KEY_CONTENT" >> "$AUTHORIZED_KEYS"
  else
    printf '%s\n' "$PUB_KEY_CONTENT" | sudo -u "$TARGET_USER" tee -a "$AUTHORIZED_KEYS" >/dev/null
  fi
fi

chmod 600 "$PRIVATE_KEY" "$AUTHORIZED_KEYS"
chmod 644 "$PUBLIC_KEY"
chown "$TARGET_USER:$TARGET_USER" "$PRIVATE_KEY" "$PUBLIC_KEY" "$AUTHORIZED_KEYS"

cat <<EOF_OUT
============================================================
GITHUB ACTIONS DEPLOY KEY READY
============================================================
Server user:
  ${TARGET_USER}
Private key on server:
  ${PRIVATE_KEY}
Public key installed in:
  ${AUTHORIZED_KEYS}

Add these GitHub Actions secrets in each app repo
(same values for every app on this server):

  USER = ${TARGET_USER}
  HOST = ${SERVER_IP}
  SSH_KEY = full contents of ${PRIVATE_KEY}
            (include BEGIN/END lines; no passphrase)

Copy private key for GitHub (run on this server):
  cat ${PRIVATE_KEY}

Test from your laptop after saving the key locally:
  ssh -i ~/.ssh/github_actions_deploy -o IdentitiesOnly=yes ${TARGET_USER}@${SERVER_IP} "echo SSH OK"

Notes:
  - This key is for CI deploys only. Keep your laptop login key separate.
  - One deploy key per server is enough for multiple apps; use different deploy_path per repo.
  - Do not commit the private key to git. Store it only in GitHub Secrets.
  - After rotating keys, remove the old public key from authorized_keys.
============================================================
EOF_OUT
