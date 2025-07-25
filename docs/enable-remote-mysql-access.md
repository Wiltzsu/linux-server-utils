# Enabling Remote MySQL Access (Hetzner Server) for Connecting with Antares (GUI for MySQL Databases)

This guide explains how to enable remote access to MySQL on a Hetzner server, allowing you to connect using Antares or any other MySQL GUI. This guide may also apply to other VPN and cloud providers.

---

## 1. Verify MySQL is Listening on Port 3306

Run the following command to check if MySQL is listening:

```bash
sudo netstat -tulpen | grep mysql
```

**Expected output:**

```
tcp 0 0 0.0.0.0:3306 0.0.0.0:* LISTEN
```

If you see `127.0.0.1:3306`, MySQL is only listening locally and will not accept remote connections.

---

### Fix: Update MySQL Configuration

Edit the MySQL config file:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

Find the line:

```ini
bind-address = 127.0.0.1
```

Change it to:

```ini
bind-address = 0.0.0.0
```

After saving the file, restart MySQL to apply changes:

```bash
sudo systemctl restart mysql
```

---

## 2. Allow Port 3306 in Hetzner Cloud Firewall

Make sure your Hetzner cloud firewall allows inbound traffic on port 3306 **only from your specific IP address**.

> **Security Note:**  
> Restricting access at the cloud firewall layer ensures that only your chosen IP can even attempt to connect to your server’s MySQL port, blocking all other sources at the network edge.

---

## 3. Allow MySQL Through UFW (Ubuntu Firewall)

Allow remote access from your local IP address:

```bash
sudo ufw allow from <YOUR.LOCAL.IP> to any port 3306 proto tcp comment 'MySQL remote access for Antares'
sudo ufw reload
```

Replace `<YOUR.LOCAL.IP>` with your actual public IP address.

Check that the rule was added:

```bash
sudo ufw status
```

> **Security Note:**  
> This step adds another layer of protection on the server itself, so only your specific IP can connect to MySQL, even if the request passes through the cloud firewall.

---

## 4. Create a Remote Access MySQL User

Log in to MySQL:

```bash
mysql -u root -p
```

Then run the following SQL commands (replace `myuser`, `YOUR.LOCAL.IP`, and `yourpassword` as needed):

```sql
CREATE USER 'myuser'@'YOUR.LOCAL.IP' IDENTIFIED BY 'yourpassword';
GRANT ALL PRIVILEGES ON *.* TO 'myuser'@'YOUR.LOCAL.IP' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

---

## 5. Verify the New User

Check if the new user exists:

```sql
SELECT user, host FROM mysql.user;
```

**Expected output should include:**

```
myuser | YOUR.LOCAL.IP
```

---

## Security Summary

By restricting access to your MySQL server at both the Hetzner cloud firewall and the server (UFW and MySQL user) layers, you ensure that only your specific IP address can connect. This layered approach significantly reduces the risk of unauthorized access.

- **Cloud firewall:** Blocks all traffic except from your IP before it reaches your server.
- **UFW (server firewall):** Only allows MySQL connections from your IP.
- **MySQL user:** Only allows logins from your IP.

---

**Note:**  
- For security, restrict access to only the necessary IP addresses.
- Consider using a strong password and limiting privileges as appropriate for your use case.