#!/command/with-contenv bash

echo "[CasaOS-UIEvents] Starting UI event registration..."

runtime_file="/var/run/casaos/message-bus.url"

echo "[CasaOS-UIEvents] Waiting for message bus to be ready..."
while [ ! -f "$runtime_file" ]; do
    sleep 1
    echo "[CasaOS-UIEvents] Still waiting for message bus URL..."
done
echo "[CasaOS-UIEvents] Message bus is ready!"

echo "[CasaOS-UIEvents] Registering UI events with message bus..."
/usr/local/bin/register-ui-events.sh
echo "[CasaOS-UIEvents] UI event registration completed!"