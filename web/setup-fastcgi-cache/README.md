# nginx FastCGI cache setup (WordPress / Bedrock)

Configures nginx to cache anonymous PHP responses via FastCGI cache. Useful for WordPress and Bedrock sites behind PHP-FPM.

---

## What it does

1. Creates `/var/cache/nginx/fastcgi` owned by `www-data`
2. Writes `/etc/nginx/conf.d/fastcgi-cache-path.conf` (cache zone in the `http` block)
3. Writes `/etc/nginx/snippets/fastcgi-cache-wordpress.conf` (bypass rules + cache directives)
4. Adds `include snippets/fastcgi-cache-wordpress.conf;` to the site’s `location ~ \.php$` block
5. Runs `nginx -t` and reloads nginx

---

## Requirements

- Ubuntu/Debian with nginx and PHP-FPM
- Site config with a standard PHP location block, e.g.:

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    ...
}
```

---

## Usage

```bash
chmod +x web/setup-fastcgi-cache/setup-fastcgi-cache.sh
sudo ./web/setup-fastcgi-cache/setup-fastcgi-cache.sh /etc/nginx/sites-available/mydevsite.conf
```

Optional tuning via environment variables:

```bash
sudo CACHE_VALID=30m CACHE_MAX_SIZE=512m \
  ./web/setup-fastcgi-cache/setup-fastcgi-cache.sh /etc/nginx/sites-available/mydevsite.conf
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CACHE_KEYS_SIZE` | `100m` | Shared memory for cache keys |
| `CACHE_MAX_SIZE` | `1g` | Max on-disk cache size |
| `CACHE_INACTIVE` | `60m` | Remove unused entries after |
| `CACHE_VALID` | `60m` | Cache successful (200) responses for |

---

## Cache bypass rules

The snippet skips cache for:

- `POST` requests
- Any URL with a query string
- Admin, login, REST API, feeds, sitemaps, `index.php`
- Logged-in WordPress users and commenters (cookie-based)

Anonymous `GET` requests to pretty permalinks are cached.

---

## Verify

```bash
curl -sI https://example.com/ | grep -i x-fastcgi-cache
```

First request: `MISS`. Repeat: `HIT`. Logged-in or admin URLs: `BYPASS`.

If the site is behind Cloudflare, test origin directly or use a cache-busting path you control.

---

## Purge cache

After publishing content changes:

```bash
sudo rm -rf /var/cache/nginx/fastcgi/*
sudo systemctl reload nginx
```

For production, consider a deploy hook or a small purge script tied to your workflow.

---

## Notes

- **Bedrock:** Document root is usually `web/`; WordPress lives under `/wp/`. The bypass patterns cover `/wp-admin/` and `/wp-login.php`.
- **Query strings:** All query strings bypass cache (common WordPress default). Adjust the snippet if you need to cache specific query args.
- **Cloudflare:** Full-page CDN cache and origin FastCGI cache can stack; tune TTLs so they do not fight each other.
- Re-running the script is safe: snippet files are rewritten; the site config is only patched once.
