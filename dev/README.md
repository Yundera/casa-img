# CasaOS Development Setup

Local development environment for CasaOS.

## Quick Start

1. Copy and configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

2. Create the data directory:
   ```bash
   sudo mkdir -p /DATA
   sudo chown 1000:1000 /DATA
   ```

3. Start the container:
   ```bash
   docker compose up -d
   ```

4. Access CasaOS at http://localhost:8080

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PCS_DOMAIN` | Yes | - | Domain for CasaOS (e.g., `nas.localhost`) |
| `PCS_DEFAULT_PASSWORD` | Yes | - | Admin user password |
| `PCS_EMAIL` | Yes | - | Email for notifications/SSL |
| `PUBLIC_IP` | Yes | - | Public IP (`127.0.0.1` for local) |
| `DATA_HOST_PATH` | No | `/DATA` | Host path for data storage |
| `PCS_DATA_ROOT` | No | `/DATA` | Container internal data path |

## Windows Setup

On Windows with Docker Desktop:

1. Create a data folder (e.g., `C:\DATA`)
2. Update `.env`:
   ```
   DATA_HOST_PATH=/c/DATA
   ```

Alternatively, use the PowerShell scripts in `win/`:
```powershell
.\win\run-simple.ps1
```

## Logs

View container logs:
```bash
docker compose logs -f casaos
```

View specific service logs inside container:
```bash
docker exec casaos cat /var/log/casaos-app-management.log
```

## Cleanup

Stop and remove:
```bash
docker compose down
```

Remove with volumes:
```bash
docker compose down -v
```
