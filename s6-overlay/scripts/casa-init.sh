#!/command/with-contenv bash

echo "CasaOS initialization starting..."

# Get UID/GID from environment variables (default to 1000 if not set)
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Using PUID=$PUID, PGID=$PGID"

# Get Docker group ID from the docker socket file
echo "Checking Docker socket permissions..."
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "999")
echo "Docker socket group ID: $DOCKER_GID"

# Ensure group with PGID exists
if ! getent group "$PGID" >/dev/null; then
  echo "Creating group casaos with GID: $PGID"
  groupadd -g "$PGID" casaos
fi

# Ensure user with PUID exists
if ! getent passwd "$PUID" >/dev/null; then
  echo "Creating user casaos with UID: $PUID and GID: $PGID"
  useradd -u "$PUID" -g "$PGID" -M -s /sbin/nologin casaos
fi

# Create necessary directories with proper ownership
echo "Creating required directories..."
mkdir -p /DATA/AppData/casaos/apps
mkdir -p /c/DATA/ # For compatibility with windows host
mkdir -p /var/log/casaos
mkdir -p /var/run/casaos

echo "Setting ownership of casaos directories..."
chown "$PUID:$PGID" /DATA
chown "$PUID:$PGID" /DATA/AppData  
chown "$PUID:$PGID" /DATA/AppData/casaos
chown "$PUID:$PGID" /DATA/AppData/casaos/apps

# Set ownership of directories that will be used by casaos processes
# Skip by default to speed up initialization (set SKIP_CHOWN=false to force ownership changes)
if [ "${SKIP_CHOWN:-true}" = "true" ]; then
    echo "Skipping ownership changes (SKIP_CHOWN=true)"
else
    echo "Setting ownership of /DATA/ directory (this may take time for large datasets)..."
    if ! chown -R "$PUID:$PGID" /DATA/ 2>/dev/null; then
        echo "Warning: Could not set ownership of /DATA/ - will continue anyway"
    fi
    echo "Setting ownership of /c/DATA/ directory..."
    if ! chown -R "$PUID:$PGID" /c/DATA/ 2>/dev/null; then
        echo "Warning: Could not set ownership of /c/DATA/ - will continue anyway"
    fi
fi
echo "Setting ownership of log and runtime directories..."
chown -R "$PUID:$PGID" /var/log/casaos
chown -R "$PUID:$PGID" /var/run/casaos
chown -R "$PUID:$PGID" /var/lib/casaos

# Create log files with proper ownership
echo "Creating log files..."
touch /var/log/casaos-gateway.log
touch /var/log/casaos-app-management.log
touch /var/log/casaos-user-service.log
touch /var/log/casaos-message-bus.log
touch /var/log/casaos-local-storage.log
touch /var/log/casaos-main.log

chown "$PUID:$PGID" /var/log/casaos-*.log

# Export environment variables for other services
echo "Exporting environment variables for services..."
echo -n "$PUID" > /var/run/s6/container_environment/PUID
echo -n "$PGID" > /var/run/s6/container_environment/PGID
echo -n "$DOCKER_GID" > /var/run/s6/container_environment/DOCKER_GID

echo "Setting up rclone socket..."
mkdir -p /var/run/rclone
touch /var/run/rclone/rclone.sock
# Ensure rclone socket has correct permissions
chown "$PUID:$PGID" /var/run/rclone/rclone.sock

# Set up timeout marker for debugging
echo "Setting up service monitoring..."
mkdir -p /var/run/casaos-status

echo "CasaOS initialization completed successfully!"
echo "==============================================="
echo "CasaOS Service Startup Summary:"
echo "- User/Group: $PUID:$PGID"
echo "- Docker Group: $DOCKER_GID"
echo "- Data Directory: /DATA/"
echo "- Skip Ownership Changes: ${SKIP_CHOWN:-true}"
echo "- Max Service Timeout: ${S6_CMD_WAIT_FOR_SERVICES_MAXTIME:-300000}ms"
echo "==============================================="
echo "Service startup order:"
echo "1. Gateway → 2. MessageBus → 3. Main → 4. LocalStorage → 5. AppManagement → 6. UserService → 7. UIEvents"
echo "==============================================="