# Store Listing Examples

Reference examples for CasaOS app store listings.

## Key Patterns

### 1. Environment Variables for Paths

Use `${APP_DATA_ROOT}` instead of hardcoded `/DATA`:

```yaml
volumes:
  - source: ${APP_DATA_ROOT}/AppData/myapp/config/
    target: /config
    type: bind
```

### 2. Network Configuration

Use `${APP_NET}` for dynamic network name:

```yaml
services:
  myapp:
    networks:
      - net  # Fixed key reference

networks:
  net:             # Fixed key (YAML keys can't be variables)
    name: ${APP_NET}  # Actual network name from env
    external: true
```

This pattern allows the network name to be configured per-environment.

### 3. Caddy Labels for Domain Routing

Add labels for automatic HTTPS routing via Caddy:

```yaml
services:
  myapp:
    labels:
      caddy: myapp.${APP_DOMAIN}
      caddy.reverse_proxy: "{{upstreams 80}}"
```

### 4. Preserve Variables in Tips

Use `$variable` syntax - these are resolved at runtime:

```yaml
x-casaos:
  tips:
    before_install:
      en_us: |
        Default password: `$APP_DEFAULT_PASSWORD`
```

## Available Environment Variables

### Platform Variables (APP_ prefix)

These are injected by the platform at `docker compose up` time.

| Variable | Description | Example |
|----------|-------------|---------|
| `APP_DATA_ROOT` | App data directory | `/DATA` |
| `APP_NET` | Docker network name | `pcs` |
| `APP_DOMAIN` | User's domain (without https://) | `user.nsl.sh` |
| `APP_DEFAULT_PASSWORD` | Default password | Set by platform |
| `APP_PUBLIC_IP` | Public IPv4 address | `1.2.3.4` |
| `APP_PUBLIC_IPV6` | Public IPv6 address | `::1` |
| `APP_EMAIL` | Admin email | `admin@user.nsl.sh` |

### Standard Variables (no prefix)

| Variable | Description | Example |
|----------|-------------|---------|
| `PUID` | User ID | `1000` |
| `PGID` | Group ID | `1000` |
| `TZ` | Timezone | `UTC` |

## Files

- `filebrowser-docker-compose.yml` - Complete example with all patterns
- `filebrowser.env.example` - Environment variables reference
