# Development Setup Guide

This guide provides detailed instructions for setting up a development environment for CasaOS containerized deployment.

## Windows Development Environment

For Windows users, reference the PowerShell scripts in the `/dev/win/` folder:

- **`build-docker-img.ps1`**: Builds the Docker image locally
- **`run-simple.ps1`**: Builds and runs a development container with Windows-specific configuration

These scripts handle Windows-specific path conversion (C:\DATA → /c/DATA) and proper volume mounting for Docker Desktop on Windows.

### Windows Script Usage

```powershell
# Build the Docker image
.\dev\win\build-docker-img.ps1

# Build and run development container
.\dev\win\run-simple.ps1
```

## NSL.sh Testing with Domain Resolution

For testing with real domain names, you can use [NSL.sh](https://nsl.sh) to get a free temporary domain that points to your local development environment. This enables testing of the full domain resolution and SSL certificate flow.

### Getting NSL.sh Credentials

1. Visit [nsl.sh](https://nsl.sh)
2. Sign up for a free account
3. Generate API credentials
4. Note your domain (e.g., `your-domain.nsl.sh`)

## Docker Compose Configurations

### Basic Development Setup

Example `docker-compose.yml` for local development:

```yaml
services:
  casaimg:
    image: nasselle/casa-img:latest
    ports:
      - "8080:8080"
    environment:
      DATA_ROOT: /DATA
      REF_DOMAIN: "nas.localhost"
      REF_NET: "bridge"
      REF_PORT: "80"
      USER: "admin:password"
    volumes:
      - ./DATA:/DATA
      - /var/run/docker.sock:/var/run/docker.sock
```

### Production-Style Setup with Mesh Router and NSL.sh

Example production-style setup using mesh-router for SSL termination and NSL.sh for domain resolution:

```yaml
services:
  mesh-router:
    image: nasselle/mesh-router:latest
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
    environment:
      # Get your provider credentials from https://nsl.sh
      - PROVIDER=https://nsl.sh,your-user-id,your-api-key
    networks:
      - pcs

  casaos:
    image: nasselle/casa-img:latest
    container_name: casaos
    hostname: casaos
    restart: unless-stopped
    environment:
      PUID: 1000
      PGID: 1000
      DATA_ROOT: "/DATA"
      REF_DOMAIN: "your-domain.nsl.sh"  # Replace with your NSL.sh domain
      REF_NET: "pcs"
      REF_PORT: "443"
      REF_SCHEME: "https"
      USER: "admin:your-secure-password"  # Replace with secure credentials
      default_pwd: "your-default-password"
      public_ip: "127.0.0.1"
    networks:
      pcs: null
    volumes:
      - ./DATA:/DATA
      - /var/run/docker.sock:/var/run/docker.sock
      - /dev:/dev  # Required for hardware device access

networks:
  pcs:
    driver: bridge
    name: pcs
```

## Configuration Notes

### NSL.sh Setup

1. **Domain Configuration**: 
   - Replace `your-domain.nsl.sh` with your actual NSL.sh domain
   - Replace `your-user-id` and `your-api-key` with credentials from NSL.sh
   - The mesh-router will automatically handle SSL certificates via Let's Encrypt

2. **Provider String Format**: 
   ```
   PROVIDER=https://nsl.sh,your-user-id,your-api-key
   ```

### Volume Mount Requirements

1. **Data Persistence**: 
   - `./DATA:/DATA` - Application data storage
   - Adjust path based on your host system requirements

2. **Docker Socket**: 
   - `/var/run/docker.sock:/var/run/docker.sock` - Required for container management

3. **Hardware Access**: 
   - `/dev:/dev` - Required for hardware device access (USB drives, etc.)

## Development Workflow

### Local Development

1. **Build and Test Locally**:
   ```bash
   # Build image
   docker build -t casa-img .
   
   # Run basic development setup
   docker-compose up -d
   ```

2. **Access the Interface**:
   - Local: `http://localhost:8080`
   - With NSL.sh: `https://your-domain.nsl.sh`
