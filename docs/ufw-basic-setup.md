# Basic UFW (Uncomplicated Firewall) Setup

This guide covers essential UFW commands and best practices for securing your server.

---

## 1. Viewing UFW Rules

- **Show all active rules (with details):**
  ```bash
  sudo ufw status verbose
  ```

- **Show rules with numbering (for easy deletion):**
  ```bash
  sudo ufw status numbered
  ```

---

## 2. Managing Rules

- **Delete a specific rule by its number:**
  ```bash
  sudo ufw delete <RULE_NUMBER>
  ```
  Replace `<RULE_NUMBER>` with the number shown in `ufw status numbered`.

---

## 3. Allowing Common Services

- **Allow SSH (port 22) from anywhere:**
  ```bash
  sudo ufw allow proto tcp to any port 22
  ```
  > **Tip:** For better security, consider restricting SSH to your IP if possible.

- **Allow HTTP (port 80):**
  ```bash
  sudo ufw allow proto tcp to any port 80
  ```

- **Allow HTTPS (port 443):**
  ```bash
  sudo ufw allow proto tcp to any port 443
  ```

---

## 4. Setting Default Policies

- **Deny all incoming connections by default:**
  ```bash
  sudo ufw default deny incoming
  ```

- **Allow all outgoing connections by default:**
  ```bash
  sudo ufw default allow outgoing
  ```

---

## 5. Enabling UFW

- **Enable the firewall (after setting your rules):**
  ```bash
  sudo ufw enable
  ```

---

## 6. Security Notes

- By default, allowing SSH from anywhere is convenient, but less secure.  
  If your IP is static, restrict SSH access to your IP:
  ```bash
  sudo ufw allow from <YOUR.IP.ADDRESS> to any port 22 proto tcp
  ```
- If your IP changes frequently, consider using [Fail2ban](https://www.fail2ban.org/) to protect SSH by blocking repeated failed login attempts.

---

**Remember:**  
Always double-check your rules before enabling UFW, especially if you are connected via SSH, to avoid locking yourself out.