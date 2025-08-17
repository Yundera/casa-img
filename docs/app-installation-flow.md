# CasaOS App Installation Flow Documentation

This document details the complete flow from API call to Docker compose execution for app installation in CasaOS-AppManagement.

## Overview

The app installation process follows a multi-layered architecture:
1. **API Layer** - REST endpoint handling
2. **Service Layer** - Business logic orchestration  
3. **Compose Layer** - Docker compose operations
4. **Docker API** - Actual container management

## Complete Installation Flow

### 1. API Entry Point

**File**: `CasaOS-AppManagement/route/v2/compose_app.go`  
**Function**: `InstallComposeApp()`  
**Endpoint**: `POST /v2/app_management/compose`

The installation process begins when a client sends a POST request with compose YAML content.

```go
func (a *AppManagement) InstallComposeApp(ctx echo.Context, params codegen.InstallComposeAppParams) error
```

#### Key Operations:
- Extract YAML from request body via `YAMLfromRequest()`
- Validate compose YAML structure
- Check for port conflicts (optional)
- Delegate to service layer

### 2. Request Processing

**File**: `CasaOS-AppManagement/route/v2/compose_app.go`

#### YAML Extraction (`YAMLfromRequest()`)
Handles both `application/yaml` and `application/json` content types:
- Direct YAML content from request body
- JSON-to-YAML conversion if needed

#### Validation (`service.NewComposeAppFromYAML()`)
- Parses compose YAML into internal structure
- Validates compose specification compliance
- Sets default values and configurations

#### Port Conflict Check (`composeApp.GetPortsInUse()`)
- Scans system for ports already in use
- Compares against compose app port mappings
- Returns validation errors if conflicts found

### 3. Service Layer Orchestration

**File**: `CasaOS-AppManagement/service/compose_service.go`  
**Function**: `ComposeService.Install()`

#### Working Directory Setup (`PrepareWorkingDirectory()`)
```go
workingDirectory := filepath.Join(config.AppInfo.AppsPath, name)
```
Creates dedicated directory at `{AppsPath}/{appName}/` for the application.

#### Compose File Persistence
```go
yamlFilePath := filepath.Join(workingDirectory, common.ComposeYAMLFileName)
os.WriteFile(yamlFilePath, composeYAMLInterpolated, 0o600)
```
Saves the compose YAML to `docker-compose.yml` in the app directory.

#### Project Loading (`LoadComposeAppFromConfigFile()`)
Reloads the compose project from the saved file with proper environment interpolation.

#### Asynchronous Installation Launch
```go
go func(ctx context.Context) {
    s.installationInProgress.Store(composeApp.Name, true)
    defer s.installationInProgress.Delete(composeApp.Name)
    
    if err := composeApp.PullAndInstall(ctx); err != nil {
        // Error handling
    }
}(ctx)
```

### 4. Compose App Operations

**File**: `CasaOS-AppManagement/service/compose_app.go`

#### Main Installation Coordinator (`PullAndInstall()`)
```go
func (a *ComposeApp) PullAndInstall(ctx context.Context) error
```

Orchestrates the complete installation process:

1. **Image Pulling** (`Pull()`)
2. **Container Creation** (`Create()`)  
3. **Service Starting** (`Start()`)

#### Image Pull Process (`Pull()`)
```go
for i, app := range a.Services {
    if err := docker.PullImage(ctx, app.Image, func(out io.ReadCloser) {
        pullImageProgress(ctx, out, "INSTALL", serviceNum, i+1)
    }); err != nil {
        // Error handling with events
    }
}
```
Downloads Docker images for all services defined in the compose file.

#### Container Creation Process
```go
if err := a.Create(ctx, api.CreateOptions{}, service); err != nil {
    go PublishEventWrapper(ctx, common.EventTypeContainerCreateError, map[string]string{
        common.PropertyTypeMessage.Name: err.Error(),
    })
    return err
}
```

Handles:
- Volume directory creation
- Device availability checking
- Container creation via Docker Compose API

#### Service Starting - **Docker Compose Up Equivalent**
```go
if err := service.Start(ctx, a.Name, api.StartOptions{
    CascadeStop: true,
    Wait:        true,
}); err != nil {
    // Error handling
}
```

**This is the actual equivalent of `docker compose up`** - starts all services defined in the compose file.

### 5. Docker API Integration

**File**: `CasaOS-AppManagement/service/compose_service.go`

#### API Service Creation (`apiService()`)
```go
func apiService() (api.Service, client.APIClient, error) {
    dockerCli, err := command.NewDockerCli()
    if err != nil {
        return nil, nil, err
    }
    
    if err := dockerCli.Initialize(&flags.ClientOptions{}); err != nil {
        return nil, nil, err
    }
    
    return compose.NewComposeService(dockerCli), dockerCli.Client(), nil
}
```

Uses the official Docker Compose v2 Go library (`github.com/docker/compose/v2`) rather than shell command execution.

## Key Files and Functions Reference

| File | Function | Purpose |
|------|----------|---------|
| `route/v2/compose_app.go` | `InstallComposeApp()` | Main API endpoint handler |
| `route/v2/compose_app.go` | `YAMLfromRequest()` | Extract YAML from HTTP request |
| `service/compose_service.go` | `Install()` | Service layer orchestration |
| `service/compose_service.go` | `PrepareWorkingDirectory()` | Create app directory |
| `service/compose_app.go` | `PullAndInstall()` | Main installation coordinator |
| `service/compose_app.go` | `Pull()` | Download Docker images |
| `service/compose_app.go` | `Create()` | Create containers |
| `service/compose_app.go` | `Up()`/`Start()` | **Start services (docker compose up)** |

## Event System

The installation process publishes events via message bus for real-time status updates:

```go
// Event types during installation
common.EventTypeAppInstallBegin
common.EventTypeImagePullBegin/End/Error
common.EventTypeContainerCreateBegin/End/Error  
common.EventTypeContainerStartBegin/End/Error
common.EventTypeAppInstallEnd/Error
```

## Error Handling

Each phase includes comprehensive error handling:
- Validation errors return HTTP 400 with specific error details
- Infrastructure errors return HTTP 500 
- Port conflicts return structured validation error responses
- Failed installations trigger cleanup of working directories

## Volume and Device Management

Before container creation:
- **Volume directories** are created if they don't exist
- **Device mappings** are filtered to only include available devices
- **Permissions** are set according to configured PUID/PGID

## Environment Variable Injection

The system automatically injects global environment variables:
```go
func (a *ComposeApp) injectEnvVariableToComposeApp() {
    for _, service := range a.Services {
        for k, v := range config.Global {
            if service.Environment[k] == nil {
                service.Environment[k] = utils.Ptr(v)
            }
        }
    }
}
```

## Summary

The complete flow from API call to Docker compose execution:

1. **HTTP Request** → `InstallComposeApp()` endpoint
2. **YAML Processing** → Parse and validate compose specification  
3. **Service Setup** → Create working directory and save compose file
4. **Image Pull** → Download required Docker images
5. **Container Creation** → Create containers via Docker Compose API
6. **Service Start** → **Execute equivalent of `docker compose up`**

The actual Docker compose up operation occurs in `service/compose_app.go` where `service.Start()` is called with the compose project configuration.