# Ubuntu Server Hardening

Step-by-step guide for hardening a fresh Ubuntu VPS after initial setup. Assumes you have root access and are targeting Ubuntu/Debian (tested on Ubuntu 24.04 LTS).

For related topics, see also:

- [UFW basic setup](ufw-basic-setup.md)
- [Create admin user](../user/create-user.sh) (`user/create-user.sh`)

---

## Overview

Recommended order:

1. Create a sudo admin user with SSH keys
2. Set a root console password (provider panel access)
3. Harden SSH
4. Configure UFW (only open required ports)
5. Bind databases to localhost
6. Enable automatic security updates
7. Install fail2ban

Keep an open SSH session and test each step in a **second terminal** before closing anything.

---

## 1. Clone utilities on the server

```bash
git clone git@github.com:YOUR_USER/linux-server-utils.git /usr/local/src/linux-server-utils
```

Run scripts with full paths or symlink individual commands into `/usr/local/bin/` if needed.

---

## 2. Create an admin user

```bash
sudo /usr/local/src/linux-server-utils/user/create-user.sh myuser
```

Copy the private key to your laptop (use the server IP from the script output):

```bash
scp root@YOUR_SERVER_IP:/home/myuser/.ssh/id_ed25519 ~/.ssh/myuser_server
chmod 600 ~/.ssh/myuser_server
```

Optional `~/.ssh/config` on your laptop:

```
Host myserver
  HostName YOUR_SERVER_IP
  User myuser
  IdentityFile ~/.ssh/myuser_server
  IdentitiesOnly yes
```

Verify before continuing:

```bash
ssh myserver
sudo whoami
groups    # should include sudo and www-data
```

Log out and back in so group membership takes effect.

After copying the key, remove the private key from the server:

```bash
sudo rm -f /home/myuser/.ssh/id_ed25519
```

Keep `authorized_keys` — that file is required for SSH login.

---

## 3. Root console password (emergency access)

Disabling root SSH does not remove root console access (e.g. Hetzner web console). Set and store a strong root password:

```bash
sudo passwd root
```

Store it in a password manager with 2FA enabled on your hosting provider account.

---

## 4. Harden SSH

Edit the SSH daemon config:

```bash
sudo nano /etc/ssh/sshd_config
```

Set these options (names must be exact):

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
AllowUsers myuser
MaxAuthTries 3
```

Add every admin username to `AllowUsers`, space-separated.

Test and reload:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Test a **new** SSH connection before closing your current session.

---

## 5. Firewall (UFW)

See [ufw-basic-setup.md](ufw-basic-setup.md) for full reference.

Basics:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
```

Check what is listening before opening ports:

```bash
sudo ss -tlnp
```

Only allow ports that need external access. Example for a server with HTTPS reverse proxy:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status numbered
```

Remove unused rules (delete highest numbers first):

```bash
sudo ufw delete <RULE_NUMBER>
```

Services on `127.0.0.1` (e.g. app on port 3000 behind nginx) do **not** need UFW rules.

---

## 6. Bind MySQL to localhost

If MySQL is only used by local apps, do not expose it publicly.

Check current binding:

```bash
sudo ss -tlnp | grep 3306
```

Edit config:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Set:

```
bind-address = 127.0.0.1
```

Restart and verify:

```bash
sudo systemctl restart mysql
sudo ss -tlnp | grep 3306
```

Remove any UFW rules that allowed remote MySQL access.

---

## 7. Automatic security updates

`unattended-upgrades` on Ubuntu installs **security updates** automatically — not full distro upgrades or major version bumps.

Install and enable:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install unattended-upgrades apt-listchanges -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

Select **Yes** when prompted.

Verify:

```bash
sudo systemctl status unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades
```

Expected content:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

Dry-run to see what would be upgraded:

```bash
sudo unattended-upgrades --dry-run --debug
```

Check if a reboot is required after kernel updates:

```bash
cat /var/run/reboot-required 2>/dev/null
```

Keep automatic reboots off unless you want them (`Unattended-Upgrade::Automatic-Reboot "false"` in `/etc/apt/apt.conf.d/50unattended-upgrades`). Reboot manually during a maintenance window when needed.

---

## 8. fail2ban

Install and enable:

```bash
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```

Create a local jail config:

```bash
sudo nano /etc/fail2ban/jail.local
```

Example configuration:

```ini
[DEFAULT]
bantime = 1d
findtime = 10m
maxretry = 3
backend = auto
banaction = iptables-multiport
banaction_allports = iptables-allports

[sshd]
port = 22
enabled = true
maxretry = 3
bantime = 1h
findtime = 10m
```

This bans an IP for **1 hour** after **3 failed SSH attempts within 10 minutes**.

Apply and verify:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

### Dynamic home IP

If your home IP changes, do **not** add it to `ignoreip` — it will become stale. If you ban yourself:

- Wait for the ban to expire, or
- Use your provider console and run: `sudo fail2ban-client set sshd unbanip YOUR.IP`

With key-only SSH, fail2ban mainly blocks automated brute-force bots, not local key passphrase entry.

### Optional: looser SSH jail

If you want fewer accidental lockouts:

```ini
[sshd]
maxretry = 5
bantime = 30m
```

---

## 9. Optional next steps

**Process manager boot persistence (PM2 example):**

```bash
sudo pm2 save
sudo pm2 startup systemd
# run the command pm2 prints, then:
sudo pm2 save
```

**Restrict SSH to a fixed IP** (only if your IP is stable):

```bash
sudo ufw delete allow OpenSSH
sudo ufw allow from YOUR.IP to any port 22 proto tcp
```

**Provider panel:** enable 2FA and optional cloud firewall.

**Monthly maintenance:**

```bash
sudo apt update && sudo apt upgrade -y
```

---

## Recovery checklist

| Problem | Fix |
|---------|-----|
| Locked out of SSH | Provider web console → login as root |
| fail2ban banned your IP | Console → `sudo fail2ban-client set sshd unbanip YOUR.IP` |
| Bad sshd_config | Console → fix file → `sudo sshd -t` → `sudo systemctl reload ssh` |
| UFW blocked SSH | Console → `sudo ufw allow OpenSSH` or `sudo ufw disable` temporarily |

---

## License

MIT — see repository root.
