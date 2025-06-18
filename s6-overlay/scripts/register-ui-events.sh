#!/command/with-contenv bash

runtime_file="/var/run/casaos/message-bus.url"

while [ ! -f "$runtime_file" ]; do
    sleep 1
    echo "Waiting for message bus URL and UI message bus file..."
done

/usr/local/bin/register-ui-events.sh