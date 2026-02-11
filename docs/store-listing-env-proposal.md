# Store Listing + .env Architecture

## Problem

Current flow converts store listing templates to fixed docker-compose files during installation. This one-shot conversion makes updates problematic because:

- The original template context is lost
- User customizations are mixed with template values
- Re-running conversion on an already-converted file is error-prone

## Solution

Keep the store listing as-is and use a separate `.env` file for customization.

## Structure

```
/DATA/AppData/casaos/apps/{app-name}/
├── docker-compose.yml   # Exact copy from store (immutable)
└── .env                 # Generated on install (user config)
```

## Flow

### Install

1. Copy `docker-compose.yml` verbatim from store listing
2. Generate `.env` with:
   - User inputs (ports, passwords, etc.)
   - Computed defaults (DATA_ROOT paths, generated secrets)

### Update

1. Replace `docker-compose.yml` with new store version
2. Keep `.env` untouched

## Store Listing Format

Store listings use standard Docker Compose variable syntax:

```yaml
services:
  app:
    image: nextcloud:${VERSION:-latest}
    environment:
      - DB_PASSWORD=${DB_PASSWORD}
    volumes:
      - ${DATA_PATH}/config:/config
    ports:
      - ${PORT:-8080}:80
```

## Why This Works

- Docker Compose natively reads `.env` from the same directory
- No custom template engine or conversion logic needed
- Clean separation: template (immutable) vs config (mutable)
- Updates are trivial: replace template, keep config
