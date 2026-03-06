#!/usr/bin/env bash
# uninstall.sh — removes the maplibre-render-server daemon.
# Optionally removes the _maplibre system user and group.
set -euo pipefail

LABEL="com.halset.maplibre-render-server"
PLIST_DST="/Library/LaunchDaemons/${LABEL}.plist"
BINARY_DST="/usr/local/bin/maplibre-render-server"
SERVICE_USER="_maplibre"
SERVICE_GROUP="_maplibre"

if [[ $EUID -ne 0 ]]; then
    echo "error: run this script with sudo." >&2
    exit 1
fi

# Stop and unload daemon
if launchctl print "system/${LABEL}" &>/dev/null; then
    echo "→ Unloading daemon..."
    launchctl bootout system "$PLIST_DST" || true
    sleep 1
fi

echo "→ Removing plist..."
rm -f "$PLIST_DST"

echo "→ Removing binary..."
rm -f "$BINARY_DST"

# Prompt before removing the system user/group
echo ""
read -rp "Remove system user and group '${SERVICE_USER}'? [y/N] " CONFIRM
if [[ "${CONFIRM,,}" == "y" ]]; then
    if dscl . -read /Users/"$SERVICE_USER" &>/dev/null; then
        echo "→ Removing user ${SERVICE_USER}..."
        dscl . -delete /Users/"$SERVICE_USER"
    fi
    if dscl . -read /Groups/"$SERVICE_GROUP" &>/dev/null; then
        echo "→ Removing group ${SERVICE_GROUP}..."
        dscl . -delete /Groups/"$SERVICE_GROUP"
    fi
else
    echo "  Keeping user/group '${SERVICE_USER}'."
fi

echo ""
echo "✓ maplibre-render-server removed."
echo "  Log files in /var/log/maplibre-render-server were left in place."
