#!/command/with-contenv bash

# This script handles service timeout scenarios
echo "[CasaOS-Timeout] Service startup timeout detected!"
echo "[CasaOS-Timeout] Services failed to start within ${S6_CMD_WAIT_FOR_SERVICES_MAXTIME}ms"
echo "[CasaOS-Timeout] Container will now exit with error status"

# Log which services might be problematic
echo "[CasaOS-Timeout] Checking service startup status..."

# Check service startup markers
if [ -f /var/run/casaos-status/gateway-started ]; then
    echo "[CasaOS-Timeout] ✓ Gateway service started"
else
    echo "[CasaOS-Timeout] ✗ Gateway service failed to start"
fi

if [ -f /var/run/casaos-status/message-bus-started ]; then
    echo "[CasaOS-Timeout] ✓ Message Bus service started"
else
    echo "[CasaOS-Timeout] ✗ Message Bus service failed to start"
fi

if [ -f /var/run/casaos-status/main-started ]; then
    echo "[CasaOS-Timeout] ✓ Main service started"
else
    echo "[CasaOS-Timeout] ✗ Main service failed to start"
fi

if [ -f /var/run/casaos-status/local-storage-started ]; then
    echo "[CasaOS-Timeout] ✓ Local Storage service started"
else
    echo "[CasaOS-Timeout] ✗ Local Storage service failed to start"
fi

if [ -f /var/run/casaos-status/app-management-started ]; then
    echo "[CasaOS-Timeout] ✓ App Management service started"
else
    echo "[CasaOS-Timeout] ✗ App Management service failed to start"
fi

if [ -f /var/run/casaos-status/user-service-started ]; then
    echo "[CasaOS-Timeout] ✓ User Service started"
else
    echo "[CasaOS-Timeout] ✗ User Service failed to start"
fi

# Check traditional runtime files
echo "[CasaOS-Timeout] Checking service runtime files..."
if [ -f /var/run/casaos/routes.json ]; then
    echo "[CasaOS-Timeout] ✓ Gateway routes file exists"
else
    echo "[CasaOS-Timeout] ✗ Gateway routes file missing"
fi

if [ -f /var/run/casaos/message-bus.url ]; then
    echo "[CasaOS-Timeout] ✓ Message Bus URL file exists"
else
    echo "[CasaOS-Timeout] ✗ Message Bus URL file missing"
fi

echo "[CasaOS-Timeout] Check Docker logs for detailed error information"
echo "[CasaOS-Timeout] Common causes: file permissions, resource limits, network issues"

# Force container to exit with error
exit 1