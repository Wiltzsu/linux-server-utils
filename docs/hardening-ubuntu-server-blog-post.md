# Hardening an Ubuntu Server: A Practical Walkthrough

When you spin up a fresh VPS, you usually get root access over SSH and not much else. That works for the first hour. After that, you want a proper admin user, key-based login, a firewall that only opens what you need, and a clear plan for when something goes wrong.

This post walks through how I hardened an Ubuntu 24.04 server on Hetzner — from creating a sudo user to locking down SSH, cleaning up UFW rules, and making sure databases aren't exposed to the internet.

---

## Start with a structured approach

Before touching production settings, I cloned my utility scripts to the server:

```
git clone git@github.com:YOUR_USER/linux-server-utils.git /usr/local/src/linux-server-utils
```

I put the repo under `/usr/local/src/` rather than `/usr/local/bin`. The latter is for executables on your PATH; source repos belong somewhere like `/usr/local/src/` or `/opt/`.

Scripts can still be run directly:

```
sudo /usr/local/src/linux-server-utils/user/create-user.sh myuser
```

Or referenced from cron with the full path.

---

## Step 1: Create an admin user (not root)

Logging in as root over SSH is convenient but risky. Bots constantly probe port 22 for root login attempts.

I use a script that:

- Creates a user with a home directory and `/bin/bash`
- Generates a random login password (for sudo and console use)
- Generates an ed25519 SSH key pair with a passphrase
- Adds the user to `sudo` and `www-data` (handy if you deploy web apps)
- Prints copy-paste instructions for your laptop

Run it as root:

```
sudo /usr/local/src/linux-server-utils/user/create-user.sh myuser
```

**On your laptop**, copy the private key off the server:

```
scp root@YOUR_SERVER_IP:/home/myuser/.ssh/id_ed25519 ~/.ssh/myuser_server
chmod 600 ~/.ssh/myuser_server
```

Add a host alias in `~/.ssh/config`:

```
Host myserver
  HostName YOUR_SERVER_IP
  User myuser
  IdentityFile ~/.ssh/myuser_server
  IdentitiesOnly yes
```

Connect with:

```
ssh myserver
```

Verify sudo works before changing anything else:

```
sudo whoami
```

**Important:** log out and back in after user creation so group membership (like `www-data`) takes effect.

---

## Step 2: Set a root password for emergencies

Disabling root SSH doesn't mean you won't need root. On Hetzner, the **web console** still lets you log in as root — useful if you lose your SSH key or lock yourself out of `sshd_config`.

Set a strong root password and store it in a password manager:

```
sudo passwd root
```

Pair this with **2FA on your Hetzner account**. Your real break-glass path is: Hetzner panel → Console → root login.

You can't recover an existing root password (it's stored as a hash). Just set a new one and save it.

---

## Step 3: Harden SSH

Edit the SSH daemon config:

```
sudo nano /etc/ssh/sshd_config
```

Set these options (names must be exact — typos like `PermitEntryPasswords` will break `sshd`):

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
AllowUsers myuser
MaxAuthTries 3
```

`AllowUsers` restricts SSH to named accounts only. Add every admin user you need, space-separated.

Test the config **before** reloading:

```
sudo sshd -t
```

If there's no output, the config is valid. Reload:

```
sudo systemctl reload ssh
```

**Critical:** keep your current SSH session open and test a **new** connection in a second terminal before closing anything.

---

## Step 4: Configure UFW — only open what you use

Default deny incoming, allow outgoing:

```
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Always allow SSH **before** enabling the firewall:

```
sudo ufw allow OpenSSH
```

See what's actually listening:

```
sudo ss -tlnp
```

Only create UFW rules for ports that need **external** access. Services bound to `127.0.0.1` (localhost) don't need firewall rules — they're not reachable from outside anyway.

For a server running a reverse proxy (nginx) in front of an app:

```
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

Review numbered rules when cleaning up:

```
sudo ufw status numbered
sudo ufw delete 5
```

Delete from the highest number downward to avoid confusion as the list renumbers.

**Don't** open ports nothing is listening on. If you have rules for 8080 or 8443 but `ss -tlnp` shows nothing there, remove them.

---

## Step 5: Lock down MySQL

If MySQL only serves apps on the same server, it should not listen on the public interface.

Check how it's bound:

```
sudo ss -tlnp | grep 3306
```

`0.0.0.0:3306` means the whole internet could reach it if the firewall allows it. Fix that in the MySQL config:

```
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Set:

```
bind-address = 127.0.0.1
```

Restart and verify:

```
sudo systemctl restart mysql
sudo ss -tlnp | grep 3306
```

You want `127.0.0.1:3306`. Remove any UFW rules that allowed remote MySQL access — they're no longer needed.

---

## Step 6: Know what's running

Before declaring the server "clean," audit active services and open ports:

```
sudo ss -tlnp
sudo systemctl list-units --type=service --state=running
```

Ask for each public port: *do I need this?* If nginx proxies to an app on port 3000 locally, you typically **don't** open 3000 in UFW — traffic flows through 443 → nginx → localhost.

Stop and disable services you no longer need:

```
sudo systemctl stop nginx
sudo systemctl disable nginx
```

But if something still depends on nginx (analytics, an API, a dashboard), keep it running. The firewall audit and `ss -tlnp` tell you what's actually required — not assumptions about whether the box is "a web server."

---

## Step 7: Process managers and recovery

If you use PM2 or similar to run Node apps, document how they're started. A process manager registry (`pm2 list`) is separate from the app files on disk — deleting PM2 entries stops the app but doesn't remove it. Recovery is usually:

```
sudo pm2 start npm --name myapp --cwd /path/to/app -- start
sudo pm2 save
sudo pm2 startup systemd
```

Always use `--cwd` when the app lives in a directory your normal user can't access (e.g. under `/root/`).

---

## What the final setup looks like

| Layer | Configuration |
|-------|---------------|
| **Admin access** | Sudo user, SSH key + passphrase, root console password in password manager |
| **SSH** | Key-only, root login disabled, `AllowUsers` set |
| **Firewall** | SSH + only required public ports (e.g. 80/443) |
| **Database** | Bound to localhost, no remote UFW rules |
| **Recovery** | Hetzner Console + rescue mode, credentials in password manager |

---

## Optional next steps

These weren't all done in the first pass but are worth adding:

**Automatic security updates:**

```
sudo apt update && sudo apt upgrade -y
sudo apt install unattended-upgrades -y
sudo dpkg-reconfigure -plow unattended-upgrades
```

**Fail2ban** (ban repeated SSH failures):

```
sudo apt install fail2ban -y
sudo systemctl enable --now fail2ban
```

**Restrict SSH to your IP** (if you have a fixed address):

```
sudo ufw delete allow OpenSSH
sudo ufw allow from YOUR.HOME.IP to any port 22 proto tcp
```

**File ownership for web deploys** — if you deploy as your user but nginx runs as `www-data`:

```
sudo chown -R myuser:www-data /var/www/mysite
sudo find /var/www/mysite -type d -exec chmod 775 {} \;
sudo find /var/www/mysite -type f -exec chmod 664 {} \;
```

---

## Lessons learned

1. **Test in a second terminal** before locking yourself out of SSH.
2. **Check `ss -tlnp`** before writing UFW rules — the firewall should mirror reality, not guesswork.
3. **Hostname ≠ reachable address** — use the server's public IP in `scp` and SSH instructions when DNS isn't set up locally.
4. **Disabling root SSH is fine** — keep the provider console and a stored root password as your safety net.
5. **"Not a web server" is too vague** — if nginx serves anything public (even a small analytics dashboard), you still need 80/443 open.

Hardening isn't a one-time task. When you add a service, check what's listening. When you remove one, clean up the firewall and stop the process. A fifteen-minute audit beats debugging `ERR_CONNECTION_REFUSED` at midnight.

---

*Tools referenced: [linux-server-utils](https://github.com/Wiltzsu/linux-server-utils) — scripts for user creation, backups, monitoring, and firewall guides.*
