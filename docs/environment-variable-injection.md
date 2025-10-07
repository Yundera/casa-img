# Environment Variable Injection in CasaOS

This document explains how environment variables are injected into Docker Compose applications when CasaOS performs `compose up` operations.

## Overview

CasaOS injects environment variables from **5 different sources** when creating or starting containers. Understanding this injection system is critical for app development and debugging.

## Injection Point

Environment variables are injected in the `injectEnvVariableToComposeApp()` function:

- **File**: `CasaOS-AppManagement/service/compose_app.go`
- **Function**: `injectEnvVariableToComposeApp()` (lines 361-371)
- **Called Before**:
  - `Up()` method at line 374 (start/restart operations)
  - `Create()` method at line 472 (initial installation)

## 5 Types of Environment Variables

### 1. OS Environment Variables (`cli.WithOsEnv`)

**Source**: All environment variables passed to the CasaOS container from the host

**Location**: `compose_app.go:895`

**Examples**:
- Any `docker run -e VAR=value`
- Docker Compose `environment:` entries in CasaOS container config

```bash
docker run -e CUSTOM_VAR=myvalue nasselle/casa-img:latest
```

### 2. Base Interpolation Map (Generated/Defaults)

**Source**: `baseInterpolationMap()` function

**Location**:
- Definition: `compose_service.go:242-249`
- Usage: `compose_app.go:885-887`

**Variables**:
- `PUID` - User ID for file ownership (default: `"1000"`)
- `PGID` - Group ID for file ownership (default: `"1000"`)
- `TZ` - System timezone (from `timeutils.GetSystemTimeZoneName()`)
- `DefaultUserName` - Default CasaOS username (from constants)
- `DefaultPassword` - Default CasaOS password (from constants)
- `AppID` - The compose app ID/name (dynamically set)

**Code Reference**:
```go
func baseInterpolationMap() map[string]string {
    return map[string]string{
        "DefaultUserName": common.DefaultUserName,
        "DefaultPassword": common.DefaultPassword,
        "PUID":            common.DefaultPUID,
        "PGID":            common.DefaultPGID,
        "TZ":              timeutils.GetSystemTimeZoneName(),
    }
}
```

### 3. .env File in Compose Directory (`cli.WithDotEnv`)

**Source**: `.env` file in the compose app's working directory

**Location**: `compose_app.go:896`

**Standard Docker Compose behavior**: If your app has a `.env` file next to `docker-compose.yml`, variables are loaded automatically.

**Example** `.env` file:
```
DATABASE_PASSWORD=secret123
API_KEY=xyz789
```

### 4. Global ENV File (`/etc/casaos/env`)

**Source**: Global environment file at `/etc/casaos/env`

**Location**:
- File path: `/etc/casaos/env` (defined in `pkg/config/config.go:11`)
- Loaded by: `config.InitGlobal()` in `pkg/config/init.go:118-148`
- Stored in: `config.Global` map
- Injected by: `injectEnvVariableToComposeApp()` in `compose_app.go:361-371`

**Format**: `KEY=VALUE` (one per line)

**Example** `/etc/casaos/env`:
```
OPENAI_API_KEY=sk-abc123
SMTP_HOST=smtp.gmail.com
SMTP_USER=user@example.com
```

**Important Behavior**:
- Only injects variables that are **not already defined** in the service's environment
- Preserves values from compose file and other sources

**Code Reference**:
```go
func (a *ComposeApp) injectEnvVariableToComposeApp() {
    for _, service := range a.Services {
        for k, v := range config.Global {
            // if there is same name var declared in environment in compose yaml
            // we should not reassign a value to it.
            if service.Environment[k] == nil {
                service.Environment[k] = utils.Ptr(v)
            }
        }
    }
}
```

### 5. PCS-Specific ENV Variables (Yundera Custom)

**Source**: Read from OS environment variables in Yundera PCS deployment

**Location**: `route/v2/appstore_pcs.go`

**Used For**: Modifying compose apps before installation/validation in Yundera's Personal Cloud Server

**Variables**:
- `DATA_ROOT` - Root path for app data storage (e.g., `/DATA`)
- `REF_NET` - Docker network to attach containers (e.g., `pcs`)
- `REF_PORT` - Default port for web access (e.g., `80` or `443`)
- `REF_DOMAIN` - Base domain for automatic subdomain generation (e.g., `mydomain.com`)
- `REF_SCHEME` - Protocol scheme: `http` or `https` (default: `http`)
- `REF_SEPARATOR` - Subdomain separator character (default: `-`)
- `REF_DEFAULT_PORT` - Fallback port when not specified (default: `80`)

**Code Reference** (`appstore_pcs_validate.go:14`):
```go
func needsModification() bool {
    envVars := []string{"DATA_ROOT", "REF_NET", "REF_PORT", "REF_DOMAIN", "REF_SCHEME", "PUID", "PGID"}
    for _, env := range envVars {
        if os.Getenv(env) != "" {
            return true
        }
    }
    return false
}
```

## Priority/Override Order

Variables are applied in this order (from **lowest** to **highest** priority):

1. **Base Interpolation Map** (defaults like PUID, PGID, TZ)
2. **OS Environment Variables** (passed to CasaOS container)
3. **.env file** in compose directory
4. **Global ENV file** (`/etc/casaos/env`) - only if not already set
5. **Compose file's `environment:` section** - always preserved (highest priority)

### Key Principle

**CasaOS never overwrites environment variables already defined in the compose file.**

It only fills in missing values from the various sources above.

## Compose File Loading Process

When loading a compose app from a config file (`LoadComposeAppFromConfigFile` at line 878):

```go
env := []string{fmt.Sprintf("%s=%s", "AppID", appID)}
for k, v := range baseInterpolationMap() {
    env = append(env, fmt.Sprintf("%s=%s", k, v))
}

project, err := options.ToProject(
    nil,
    nil,
    cli.WithWorkingDirectory(options.ProjectDir),
    cli.WithOsEnv,              // OS environment variables
    cli.WithDotEnv,             // .env file in compose directory
    cli.WithEnv(env),           // Base interpolation map
    cli.WithConfigFileEnv,      // Compose file environment
    cli.WithDefaultConfigPath,
    cli.WithEnvFiles(options.EnvFiles...),
    cli.WithName(options.ProjectName),
)
```

## Usage Examples

### Example 1: Using Global ENV File

To make an API key available to all apps:

1. Edit `/etc/casaos/env`:
```bash
echo "OPENAI_API_KEY=sk-abc123" >> /etc/casaos/env
```

2. Restart CasaOS-AppManagement service to reload the file

3. Any app can now use `$OPENAI_API_KEY` in their compose file:
```yaml
services:
  myapp:
    image: myapp:latest
    environment:
      - OPENAI_API_KEY=$OPENAI_API_KEY
```

### Example 2: Overriding Defaults

Compose file with explicit PUID/PGID (overrides base interpolation):

```yaml
services:
  myapp:
    image: myapp:latest
    environment:
      - PUID=1001  # Overrides default 1000
      - PGID=1001  # Overrides default 1000
```

### Example 3: PCS Automatic Configuration

In Yundera PCS deployment with these env vars:
```bash
DATA_ROOT=/DATA
REF_NET=pcs
REF_DOMAIN=mydomain.com
REF_PORT=443
REF_SCHEME=https
```

Apps automatically get:
- Volumes mapped to `/DATA/AppData/{appname}/...`
- Connected to `pcs` network
- Accessible at `{appname}.mydomain.com` via HTTPS

## Debugging Environment Variables

### Check What Variables Are Set

1. **View global env file**:
```bash
cat /etc/casaos/env
```

2. **Check OS environment in CasaOS container**:
```bash
docker exec casaos env | grep -E "PUID|PGID|REF_|DATA_ROOT"
```

3. **Inspect running container**:
```bash
docker inspect <container-name> | jq '.[0].Config.Env'
```

### Common Issues

**Issue**: App doesn't see expected environment variable

**Solutions**:
1. Check if variable is in compose file `environment:` section
2. Verify `/etc/casaos/env` is properly formatted (KEY=VALUE, one per line)
3. Restart CasaOS-AppManagement service after editing `/etc/casaos/env`
4. Check that variable isn't being overridden by compose file

**Issue**: Wrong PUID/PGID causing permission errors

**Solutions**:
1. Set `PUID` and `PGID` as OS env vars when starting CasaOS container
2. Or add to `/etc/casaos/env`:
```
PUID=1001
PGID=1001
```

## Related Files

- `CasaOS-AppManagement/service/compose_app.go` - Main injection logic
- `CasaOS-AppManagement/service/compose_service.go` - Base interpolation map
- `CasaOS-AppManagement/pkg/config/init.go` - Global env file loading
- `CasaOS-AppManagement/route/v2/appstore_pcs.go` - PCS-specific modifications
- `CasaOS-AppManagement/route/v2/appstore_pcs_validate.go` - PCS validation logic
