#!/bin/bash
set -euo pipefail

# Usage: sudo ./create-user.sh [username]
# Run as root. Generates login password and SSH key passphrase automatically.

random_string() {
  local length="${1:?length required}"
  local charset='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*-_=+'
  local out=""
  local charset_len=${#charset}

  while ((${#out} < length)); do
    local byte
    byte=$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')
    out+="${charset:$((byte % charset_len)):1}"
  done

  printf '%s' "$out"
}

USERNAME="${1:-}"
if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0 [username]" >&2
  exit 1
fi
if [[ -z "$USERNAME" ]]; then
  read -rp "Username: " USERNAME
fi
if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "Invalid username." >&2
  exit 1
fi
if id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' already exists." >&2
  exit 1
fi

LOGIN_PASS="$(random_string 20)"
KEY_PASSPHRASE="$(random_string 16)"

HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"
# Create user with home dir and bash shell
useradd -m -s /bin/bash "$USERNAME"
# Set login password
echo "$USERNAME:$LOGIN_PASS" | chpasswd
# Add to sudo group
usermod -aG sudo "$USERNAME"
# SSH setup
USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
PRIVATE_KEY="$SSH_DIR/id_ed25519"
PUBLIC_KEY="$SSH_DIR/id_ed25519.pub"
LOCAL_KEY_NAME="${USERNAME}_${HOSTNAME_SHORT}"
install -d -m 700 -o "$USERNAME" -g "$USERNAME" "$SSH_DIR"
# Generate ed25519 key with passphrase
ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -N "$KEY_PASSPHRASE" -C "$USERNAME@${HOSTNAME_FQDN}"
# Install public key for login (this server uses key-only SSH)
cat "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
chown "$USERNAME:$USERNAME" "$AUTHORIZED_KEYS" "$PRIVATE_KEY" "$PUBLIC_KEY"
chmod 600 "$AUTHORIZED_KEYS" "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"
LOCAL_KEY_PATH="\$HOME/.ssh/${LOCAL_KEY_NAME}"
SSH_LOGIN="ssh -i ${LOCAL_KEY_PATH} ${USERNAME}@${HOSTNAME_FQDN}"
cat <<EOF_OUT
============================================================
USER CREATED SUCCESSFULLY
============================================================
Username:
  ${USERNAME}
Login password:
  ${LOGIN_PASS}
SSH key passphrase:
  ${KEY_PASSPHRASE}
SSH login command (after copying key to your machine):
  ${SSH_LOGIN}
Private key on server:
  ${PRIVATE_KEY}
Copy key to your laptop:
  scp root@${HOSTNAME_FQDN}:${PRIVATE_KEY} ~/.ssh/${LOCAL_KEY_NAME}
  chmod 600 ~/.ssh/${LOCAL_KEY_NAME}
Optional ~/.ssh/config entry:
  Host ${HOSTNAME_SHORT}
    HostName ${HOSTNAME_FQDN}
    User ${USERNAME}
    IdentityFile ~/.ssh/${LOCAL_KEY_NAME}
Then connect with:
  ssh ${HOSTNAME_SHORT}
Notes:
  - SSH on this server is key-only; the passphrase unlocks the private key.
  - The login password is for sudo and local/console use.
  - Save these credentials somewhere safe, then remove this output from history.
  - After login works, consider:
      PermitRootLogin no
      AllowUsers ${USERNAME}
      systemctl reload ssh
Optional cleanup after copying the key:
  rm -f ${PRIVATE_KEY}
============================================================
EOF_OUT
