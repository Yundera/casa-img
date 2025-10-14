# Yundera CasaIMG 

This Casa OS build is the custom OS Web-UI for Yundera.
This project aims to deliver CasaOS (https://github.com/IceWhaleTech/CasaOS) as a docker container.

## Sponsor
Thanks for sponsoring this project

**Yundera** : [yundera.com](https://yundera.com) - Easy to use cloud server for open source container applications.

## Sibling project
[Mesh-Router](https://github.com/worph/mesh-router) - providing easy management of for domain accessible containers and compatible with CasaIMG.


## Prerequisites
- Docker must be installed on the host (works on Windows and Linux host)
- At least 150MB of RAM

## Getting Started

The image is now available on DockerHub! You can either pull the official image or build it yourself.

### Pull from DockerHub
```bash
docker pull nasselle/casa-img:latest
```

## Running the Container

### Example: Running from Docker Command Line

```bash
docker run -d \
    -p 8080:8080 \
    -e REF_NET=meta \  # optional, the network to attach the container created by CasaIMG
    -e REF_PORT=80 \  # optional, the published port for the WEB-UI of a new container installation
    -e REF_DOMAIN=nas.localhost \  # optional, the published hostname for the WEB-UI of a new container installation
    -e DATA_ROOT=/c/DATA \  # mandatory, path where the data are located (Windows /c/path/DATA or Linux /path/DATA)
    -e USER=admin:password \  # optional, automatically register user with specified credentials
    -v C:\DATA:/DATA \  # mandatory, where persistent data and app volume will be stored
    -v /var/run/docker.sock:/var/run/docker.sock \  # mandatory, allows CasaIMG to control the docker host
    --name casaimg nasselle/casa-img:latest
```

### Example: Docker Compose

Create a `docker-compose.yml` file with the following content:

```yaml
services:
  casaimg:
    image: nasselle/casa-img:latest
    ports:
      - "8080:8080"
    environment:
      REF_NET: meta  # optional
      REF_PORT: 80  # optional
      REF_DOMAIN: nas.localhost  # optional
      DATA_ROOT: /c/DATA  # mandatory, path where the data are located (Windows /c/DATA or Linux /path/DATA)
      USER: "admin:password"  # optional, automatically register user with specified credentials
    volumes:
      - C:\DATA:/DATA  # mandatory, where persistent data and app volume will be stored
      - /var/run/docker.sock:/var/run/docker.sock  # mandatory, allows CasaIMG to control the docker host
```

To start the service with Docker Compose, run:
```bash
docker-compose up -d
```

### Access the Web Interface
Once the container is running, open [http://localhost:8080](http://localhost:8080) in your browser to access the web interface.

## Network Configuration

CasaIMG provides environment variables to configure how new containers started by CasaOS can be accessed. This is particularly useful when running your NAS behind a router and want to make services accessible.

### Environment Variables

| Variable | Description | Example | Default |
|----------|-------------|---------|---------|
| REF_NET | Docker network to attach new containers to | `meta` | `bridge` |
| REF_PORT | Default published port for container web interfaces | `80` | Container's default |
| REF_DOMAIN | Base domain for automatic subdomain generation | `domain.com` | none |
| USER | Automatically create an admin user on first startup (format: `username:password`) | `admin:mypassword` | none |
| PUID | User ID for file permissions | `1000` | `1000` |
| PGID | Group ID for file permissions | `1000` | `1000` |
| SKIP_CHOWN | Skip recursive ownership changes for faster startup | `false` | `true` |
| S6_CMD_WAIT_FOR_SERVICES_MAXTIME | Service startup timeout in milliseconds | `300000` | `300000` |
| S6_BEHAVIOUR_IF_STAGE2_FAILS | Container behavior on service failure (2=exit) | `1` | `2` |

### Domain Configuration Example

When `REF_DOMAIN` is set, CasaOS automatically assigns subdomains to new containers using the pattern: `{container-name}.{domain}`.

For example, with `REF_DOMAIN=domain.com`:
```
nginx container  → nginx.domain.com
plex container  → plex.domain.com
nextcloud container → nextcloud.domain.com
```

### Common Setup Scenarios

1. **Behind a Reverse Proxy (Recommended)**
```yaml
services:
  casaimg:
    environment:
      REF_DOMAIN: "mydomain.com"  # All apps will get a subdomain under mydomain.com
      REF_NET: "proxy"            # Attach to your reverse proxy network
      REF_PORT: "443"              # Default HTTPS port (configure you proxy to handle https requests)
```
Configure your reverse proxy (like Traefik, Nginx Proxy Manager) to handle `*.mydomain.com`.

2**Local Network Only**
```yaml
services:
  casaimg:
    environment:
      REF_DOMAIN: "nas.local"    # Local domain for LAN access -> will gives nginx.nas.local
      REF_PORT: "80"             # Default HTTP port
```

### Notes
- When using domains, ensure your DNS or reverse proxy is properly configured to route traffic to the correct containers
- The domain feature works best with a reverse proxy that supports automatic SSL certificate generation
- If no domain is specified, containers will be accessible via IP:PORT
- REF_PORT defines the default external port for web interfaces of new containers
- Container-specific ports can still be configured individually through CasaOS interface

## Volume Directory Preparation

CasaIMG automatically prepares volume directories when installing applications to ensure proper permissions and ownership. This feature helps prevent common permission issues with containerized applications.

### How It Works

When installing an application, CasaIMG automatically:

1. **Scans Docker Compose volumes** - Identifies all volume mounts for the application
2. **Filters by DATA_ROOT** - Only processes directories under your configured `DATA_ROOT` path
3. **Creates directories** - Uses `mkdir -p` behavior to create the directory and any missing parent directories
4. **Sets ownership** - Assigns ownership to `PUID:PGID` for newly created directories only
5. **Preserves existing directories** - Never changes ownership of directories that already exist

### Requirements for Processing

A volume path must meet **all** these criteria to be processed:

- ✅ Path starts with `DATA_ROOT` (e.g., `/DATA/appname/config/`)
- ✅ Path ends with `/` (to avoid accidentally creating files instead of directories)  
- ✅ Directory doesn't already exist (existing directories are left untouched)

### Example

```yaml
# Docker Compose for an application
services:
  myapp:
    volumes:
      - /DATA/myapp/config/:/app/config    # ✅ Will be processed
      - /DATA/myapp/data/:/app/data        # ✅ Will be processed  
      - /DATA/shared/:/app/shared          # ❌ Missing trailing slash, skipped
      - /external/backup:/backup           # ❌ Outside DATA_ROOT, skipped
      - myapp-cache:/tmp/cache             # ❌ Named volume, skipped
```

With `PUID=1000` and `PGID=1000`, CasaIMG would:
- Create `/DATA/myapp/config/` owned by `1000:1000`
- Create `/DATA/myapp/data/` owned by `1000:1000`
- Skip `/DATA/shared/` (no trailing slash)
- Skip `/external/backup` (outside DATA_ROOT)
- Skip `myapp-cache` (named volume, not bind mount)

### Benefits

- **No permission errors** - Applications can immediately write to their data directories
- **Consistent ownership** - All application data uses the same PUID:PGID  
- **Safe operation** - Never modifies existing directories or files
- **Automatic process** - No manual intervention required during app installation

### Environment Variables

| Variable | Purpose | Default | Example |
|----------|---------|---------|---------|
| `PUID` | User ID for new directories | `1000` | `1000` |
| `PGID` | Group ID for new directories | `1000` | `1000` |
| `DATA_ROOT` | Base path for application data | *required* | `/DATA` |

### Troubleshooting

If you encounter permission issues:

1. **Check DATA_ROOT** - Ensure it matches your volume mount path
2. **Check trailing slashes** - Volume paths in Docker Compose should end with `/`
3. **Verify PUID/PGID** - Should match the user running containers
4. **Check logs** - CasaIMG logs all directory creation and ownership changes

# Development Setup

## Repository Structure

This project uses modified versions of the CasaOS repositories to add features useful for the Docker image, such as domain/port/network support configured by environment variables. If you want to use the original CasaOS project, you can change the submodules to point directly to the original repositories:

Example:
```bash
# Modified version (current)
https://github.com/worph/CasaOS-MessageBus.git

# Original version
https://github.com/IceWhaleTech/CasaOS-MessageBus.git
```

## Clone the Repository

Option 1: Fresh clone (recommended)
```bash
git clone --recurse-submodules --remote-submodules https://github.com/worph/casa-img.git
cd casa-img
```

Option 2: If already cloned
```bash
git submodule update --init --recursive
```

## Configure Git Submodules

Run these commands once to properly configure submodule handling:
```bash
# Configure submodule behavior
git config submodule.recurse true
git config push.recurseSubmodules check
git config submodule.recurseSubmodules true

# Update all submodules to their correct branches
git submodule update --init --recursive --merge

# to cleanup (reset) the submodule
git submodule deinit -f .
git submodule update --init --recursive
```

## Build the Image
```bash
npx dockflow build
```

## Submodule Versions

This project integrates various CasaOS components as submodules. Each submodule is tracked at a specific version to ensure stability and compatibility.

| Component | Branch            | Version        | Upstream Repository |
|-----------|-------------------|----------------|-------------------|
| CasaOS | main              | v0.4.15        | [IceWhaleTech/CasaOS](https://github.com/IceWhaleTech/CasaOS) |
| CasaOS-AppManagement | casa-img          | v0.4.16-alpha2 | [IceWhaleTech/CasaOS-AppManagement](https://github.com/IceWhaleTech/CasaOS-AppManagement) |
| CasaOS-AppStore | main              | no version     | [IceWhaleTech/CasaOS-AppStore](https://github.com/IceWhaleTech/CasaOS-AppStore) |
| CasaOS-Gateway | main              | v0.4.8         | [IceWhaleTech/CasaOS-Gateway](https://github.com/IceWhaleTech/CasaOS-Gateway) |
| CasaOS-LocalStorage | main              | v0.4.5-2       | [IceWhaleTech/CasaOS-LocalStorage](https://github.com/IceWhaleTech/CasaOS-LocalStorage) |
| CasaOS-MessageBus | main              | v0.4.5         | [IceWhaleTech/CasaOS-MessageBus](https://github.com/IceWhaleTech/CasaOS-MessageBus) |
| CasaOS-UI | casa-img | 0.4.20         | [IceWhaleTech/CasaOS-UI](https://github.com/IceWhaleTech/CasaOS-UI) |
| CasaOS-UserService | casa-img          | v0.4.8         | [IceWhaleTech/CasaOS-UserService](https://github.com/IceWhaleTech/CasaOS-UserService) |
| CasaOS-CLI | main              | v0.4.4         | [IceWhaleTech/CasaOS-CLI](https://github.com/IceWhaleTech/CasaOS-CLI) |
## Support

Need help? Join our Discord community: [https://discord.gg/QJyuNDXuFa](https://discord.gg/QJyuNDXuFa)