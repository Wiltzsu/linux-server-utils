# Setting Up Postfix and Mailutils for Outgoing Email

This guide will help you install and configure Postfix and mailutils on your server, including setting up an external SMTP relay (such as Gmail) for reliable outgoing email.

---

## 1. Install Mail Utilities

Update your package list and install `mailutils` and `postfix`:

```bash
sudo apt update
sudo apt install mailutils postfix -y
```

---

## 2. Postfix Installation Prompts

During installation, you will be prompted for configuration options:

- **Configuration Type:**  
  Select **Internet Site**.

- **System Mail Name:**  
  Enter your server’s fully qualified domain name (FQDN), e.g.  
  `myserver.example.com` or `your-hostname.yourdomain.com`.

---

## 3. Configure External SMTP Relay (e.g., Gmail)

If your provider blocks outbound port 25 or you want to use authenticated SMTP, configure Postfix to relay through an external SMTP server.

### Edit Postfix Main Configuration

Open the main configuration file:

```bash
sudo nano /etc/postfix/main.cf
```

Add or update the following lines:

```ini
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
```

---

### Set Up SMTP Authentication

Create the password file:

```bash
sudo nano /etc/postfix/sasl_passwd
```

Add this line (replace with your Gmail address and [App Password](https://support.google.com/accounts/answer/185833)):

```
[smtp.gmail.com]:587 your_email@gmail.com:your_app_password
```

Secure and hash the password file:

```bash
sudo postmap /etc/postfix/sasl_passwd
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
```

---

### Restart Postfix

```bash
sudo systemctl restart postfix
```

---

## 4. Check Postfix Logs

To verify mail delivery and troubleshoot, check the mail log:

```bash
sudo tail -n 50 /var/log/mail.log
```

---

## Notes

- For Gmail, you must use an [App Password](https://support.google.com/accounts/answer/185833) if 2FA is enabled.
- Your server’s FQDN should resolve to your server’s public IP for best results.
- This setup allows scripts and cron jobs to send email using the `mail` command.
