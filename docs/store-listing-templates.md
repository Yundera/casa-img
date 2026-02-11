# Store Listing Template Variables

This document explains how to use template variables in CasaOS app store listings to configure domain routing, reverse proxy labels, and web access URLs.

## Overview

Store listings use template variables that get substituted with PCS (Personal Cloud Server) environment values at installation time. This gives store authors full control over:

- **Domain/hostname patterns** for web access
- **Reverse proxy labels** (Compass, Traefik, etc.)
- **URL display** in the CasaOS UI

Template variables use the `${variable}` syntax and are replaced with actual values from the PCS environment.

## Available Template Variables

| Variable | Source | Example Value | Description |
|----------|--------|---------------|-------------|
| `${domain}` | `REF_DOMAIN` | `mydomain.nsl.sh` | Base domain for the PCS |
| `${scheme}` | `REF_SCHEME` | `https` | Protocol (http or https) |
| `${port}` | `REF_PORT` | `443` | External port for web access |
| `${name}` | Compose app name | `immich` | The application's compose project name |

## Where Template Variables Are Substituted

Template substitution occurs in these locations within the compose file:

### 1. Service Labels

All service labels support template variable substitution:

```yaml
services:
  immich:
    image: ghcr.io/immich-app/immich-server:release
    labels:
      compass: "${name}-${domain}"
      compass.reverse_proxy: "{{upstreams 3001}}"
```

**Result** (with `REF_DOMAIN=mydomain.nsl.sh`):
```yaml
labels:
  compass: "immich-mydomain.nsl.sh"
  compass.reverse_proxy: "{{upstreams 3001}}"
```

### 2. x-casaos Extension Fields

The `x-casaos` extension fields support template substitution:

```yaml
x-casaos:
  hostname: "${name}-${domain}"
  scheme: "${scheme}"
  port_map: "${port}"
  index: /
```

## Compass Label Configuration

[Compass](https://github.com/Yundera/mesh-router-compass) is a Caddy-docker-proxy inspired label system for dynamic reverse proxy configuration. Store listings define Compass labels directly with template variables.

### Basic Compass Configuration

```yaml
services:
  myapp:
    image: myapp:latest
    labels:
      compass: "${name}-${domain}"
      compass.reverse_proxy: "{{upstreams 8080}}"
```

### Compass Label Reference

| Label | Description | Example |
|-------|-------------|---------|
| `compass` | The hostname/domain for this service | `myapp-${domain}` |
| `compass.reverse_proxy` | Upstream configuration | `{{upstreams 3000}}` |

### Custom Subdomain Patterns

Store authors control the exact subdomain pattern:

```yaml
# Standard: appname-domain.com
labels:
  compass: "${name}-${domain}"

# Port-prefixed: 8080-appname-domain.com
labels:
  compass: "8080-${name}-${domain}"

# Custom name: photos-domain.com
labels:
  compass: "photos-${domain}"

# Nested subdomain: app.photos-domain.com
labels:
  compass: "app.photos-${domain}"
```

## Complete Store Listing Example

### Simple Web Application

```yaml
version: "3.8"

services:
  nginx:
    image: nginx:alpine
    labels:
      compass: "${name}-${domain}"
      compass.reverse_proxy: "{{upstreams 80}}"
    volumes:
      - ${DATA_ROOT}/AppData/${name}/html:/usr/share/nginx/html

x-casaos:
  hostname: "${name}-${domain}"
  scheme: "${scheme}"
  port_map: "${port}"
  index: /
  title:
    en_us: Nginx
  category: Utilities
  icon: https://example.com/nginx-icon.png
```

### Multi-Service Application (Immich)

```yaml
version: "3.8"

services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    labels:
      compass: "${name}-${domain}"
      compass.reverse_proxy: "{{upstreams 3001}}"
    environment:
      - DB_HOSTNAME=immich-db
      - REDIS_HOSTNAME=immich-redis
    volumes:
      - ${DATA_ROOT}/AppData/${name}/upload:/usr/src/app/upload
    depends_on:
      - immich-db
      - immich-redis

  immich-db:
    image: postgres:14
    environment:
      - POSTGRES_DB=immich
      - POSTGRES_USER=immich
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - ${DATA_ROOT}/AppData/${name}/db:/var/lib/postgresql/data

  immich-redis:
    image: redis:alpine
    volumes:
      - ${DATA_ROOT}/AppData/${name}/redis:/data

x-casaos:
  main: immich-server
  hostname: "${name}-${domain}"
  scheme: "${scheme}"
  port_map: "${port}"
  index: /
  title:
    en_us: Immich
  description:
    en_us: Self-hosted photo and video backup solution
  category: Media
  icon: https://immich.app/img/logo.svg
```

### Application with Non-Standard Port in Subdomain

For apps where you want the port visible in the subdomain (useful when running multiple instances):

```yaml
services:
  code-server:
    image: linuxserver/code-server
    labels:
      compass: "8443-${name}-${domain}"
      compass.reverse_proxy: "{{upstreams 8443}}"
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - ${DATA_ROOT}/AppData/${name}/config:/config

x-casaos:
  hostname: "8443-${name}-${domain}"
  scheme: "${scheme}"
  port_map: "${port}"
  index: /
  title:
    en_us: Code Server
```

## URL Construction

The final user-facing URL is constructed from the resolved template values:

```
${scheme}://${hostname}:${port}${index}
```

**Example** with:
- `REF_SCHEME=https`
- `REF_DOMAIN=mydomain.nsl.sh`
- `REF_PORT=443`
- `hostname: "${name}-${domain}"` (app name: `immich`)
- `index: /`

**Result**: `https://immich-mydomain.nsl.sh:443/`

## Migration from Legacy Format

### Old Format (Implicit)

```yaml
x-casaos:
  webui_port: 3001
  index: /
```

The system would auto-generate hostname based on port detection logic.

### New Format (Explicit)

```yaml
services:
  myapp:
    labels:
      compass: "${name}-${domain}"
      compass.reverse_proxy: "{{upstreams 3001}}"

x-casaos:
  hostname: "${name}-${domain}"
  scheme: "${scheme}"
  port_map: "${port}"
  index: /
```

The store author explicitly defines the pattern they want.

## Best Practices

### 1. Use `${name}` for Consistency

Using `${name}` instead of hardcoding the app name ensures the hostname matches the compose project name:

```yaml
# Good - uses variable
compass: "${name}-${domain}"

# Avoid - hardcoded name
compass: "immich-${domain}"
```

### 2. Keep Compass and x-casaos Hostname in Sync

The `compass` label and `x-casaos.hostname` should match so the UI displays the correct URL:

```yaml
labels:
  compass: "${name}-${domain}"

x-casaos:
  hostname: "${name}-${domain}"  # Same pattern
```

### 3. Document Custom Subdomains

If using a custom subdomain pattern, add a tip for users:

```yaml
x-casaos:
  hostname: "photos-${domain}"
  tips:
    before_install:
      en_us: "This app will be accessible at photos-yourdomain.com"
```

## Troubleshooting

### Variable Not Substituted

If you see literal `${domain}` in labels after installation:

1. Verify the PCS environment variables are set (`REF_DOMAIN`, etc.)
2. Check the variable name is spelled correctly (case-sensitive)
3. Ensure the variable is in the supported list

### Wrong Hostname

If the generated hostname is incorrect:

1. Check the `hostname` template in `x-casaos`
2. Verify `compass` label matches the expected pattern
3. Confirm `REF_DOMAIN` is set correctly on the PCS

### Compass Not Routing

If Compass isn't routing traffic to the app:

1. Verify the `compass` label is on the correct service (the one with the web UI)
2. Check `compass.reverse_proxy` points to the correct internal port
3. Ensure the container is on the correct network (`REF_NET`)
