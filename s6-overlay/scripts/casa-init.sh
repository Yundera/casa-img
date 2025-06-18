#!/command/with-contenv bash

# Get UID/GID from environment variables (default to 1000 if not set)
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Get Docker group ID from the docker socket file
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "999")
#ls -al /var/run/docker.sock

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
mkdir -p /DATA/AppData/casaos/apps
mkdir -p /c/DATA/ # For compatibility with windows host
mkdir -p /var/log/casaos
mkdir -p /var/run/casaos

# Set ownership of directories that will be used by casaos processes
chown -R "$PUID:$PGID" /DATA/
chown -R "$PUID:$PGID" /c/DATA/
chown -R "$PUID:$PGID" /var/log/casaos
chown -R "$PUID:$PGID" /var/run/casaos
chown -R "$PUID:$PGID" /var/lib/casaos

# Create log files with proper ownership
touch /var/log/casaos-gateway.log
touch /var/log/casaos-app-management.log
touch /var/log/casaos-user-service.log
touch /var/log/casaos-message-bus.log
touch /var/log/casaos-local-storage.log
touch /var/log/casaos-main.log

chown "$PUID:$PGID" /var/log/casaos-*.log

# Export environment variables for other services
echo -n "$PUID" > /var/run/s6/container_environment/PUID
echo -n "$PGID" > /var/run/s6/container_environment/PGID
echo -n "$DOCKER_GID" > /var/run/s6/container_environment/DOCKER_GID

mkdir -p /var/run/rclone
touch /var/run/rclone/rclone.sock
# Ensure rclone socket has correct permissions
chown "$PUID:$PGID" /var/run/rclone/rclone.sock

echo "Starting CasaOS services as UID:GID $PUID:$PGID..."
echo "Docker group ID: $DOCKER_GID"