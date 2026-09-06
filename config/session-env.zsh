# Standard per-user D-Bus connection for headless native applications.
# Leave an explicitly supplied session bus untouched.
if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} && -S /run/user/$EUID/bus ]]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$EUID/bus"
fi
