#!/usr/bin/env bash
# install.sh — builds and installs maplibre-render-server as a launchd daemon.
# Creates a dedicated least-privilege system user (_maplibre) to run the service.
# Run with: sudo ./install.sh
set -euo pipefail

LABEL="com.halset.maplibre-render-server"
PLIST_SRC="launchd/${LABEL}.plist"
PLIST_DST="/Library/LaunchDaemons/${LABEL}.plist"
BINARY_DST="/usr/local/bin/maplibre-render-server"
LOG_DIR="/var/log/maplibre-render-server"
SERVICE_USER="_maplibre"
SERVICE_GROUP="_maplibre"

if [[ $EUID -ne 0 ]]; then
    echo "error: run this script with sudo." >&2
    exit 1
fi

# ── 1. Create dedicated system group ─────────────────────────────────────────
if dscl . -read /Groups/"$SERVICE_GROUP" &>/dev/null; then
    echo "→ Group ${SERVICE_GROUP} already exists, skipping."
else
    echo "→ Creating system group ${SERVICE_GROUP}..."
    # Find a free GID in the system range (300–499)
    GID=300
    while dscl . -list /Groups PrimaryGroupID | awk '{print $2}' | grep -qx "$GID"; do
        GID=$((GID + 1))
    done
    echo "  Using GID ${GID}"
    dscl . -create /Groups/"$SERVICE_GROUP"
    dscl . -create /Groups/"$SERVICE_GROUP" PrimaryGroupID "$GID"
    dscl . -create /Groups/"$SERVICE_GROUP" RealName "MapLibre Render Server"
    dscl . -create /Groups/"$SERVICE_GROUP" Password "*"
fi

GID=$(dscl . -read /Groups/"$SERVICE_GROUP" PrimaryGroupID | awk '{print $2}')

# ── 2. Create dedicated system user ──────────────────────────────────────────
if dscl . -read /Users/"$SERVICE_USER" &>/dev/null; then
    echo "→ User ${SERVICE_USER} already exists, skipping."
else
    echo "→ Creating system user ${SERVICE_USER}..."
    # Find a free UID in the system range (300–499)
    UID_VAL=300
    while dscl . -list /Users UniqueID | awk '{print $2}' | grep -qx "$UID_VAL"; do
        UID_VAL=$((UID_VAL + 1))
    done
    echo "  Using UID ${UID_VAL}"
    dscl . -create /Users/"$SERVICE_USER"
    dscl . -create /Users/"$SERVICE_USER" UniqueID        "$UID_VAL"
    dscl . -create /Users/"$SERVICE_USER" PrimaryGroupID  "$GID"
    dscl . -create /Users/"$SERVICE_USER" RealName        "MapLibre Render Server"
    dscl . -create /Users/"$SERVICE_USER" UserShell       /usr/bin/false
    dscl . -create /Users/"$SERVICE_USER" NFSHomeDirectory /var/empty
    dscl . -create /Users/"$SERVICE_USER" Password        "*"
    # Hide from the login window
    dscl . -create /Users/"$SERVICE_USER" IsHidden        1
fi

# ── 3. Build release binary ───────────────────────────────────────────────────
echo "→ Building release binary..."
sudo -u "$SUDO_USER" swift build -c release

# ── 4. Install binary ────────────────────────────────────────────────────────
echo "→ Installing binary to ${BINARY_DST}..."
cp .build/release/App "$BINARY_DST"
chown root:wheel "$BINARY_DST"
chmod 755 "$BINARY_DST"

# ── 5. Create log directory owned by the service user ────────────────────────
echo "→ Creating log directory ${LOG_DIR}..."
mkdir -p "$LOG_DIR"
chown "$SERVICE_USER":"$SERVICE_GROUP" "$LOG_DIR"
chmod 750 "$LOG_DIR"

# ── 6. Install launchd plist ─────────────────────────────────────────────────
echo "→ Installing plist to ${PLIST_DST}..."
cp "$PLIST_SRC" "$PLIST_DST"
chown root:wheel "$PLIST_DST"
chmod 644 "$PLIST_DST"

# ── 7. Load (or reload) the daemon ───────────────────────────────────────────
if launchctl print "system/${LABEL}" &>/dev/null; then
    echo "→ Unloading existing daemon..."
    launchctl bootout system "$PLIST_DST" || true
    sleep 1
fi

echo "→ Bootstrapping daemon..."
launchctl bootstrap system "$PLIST_DST"

echo ""
echo "✓ maplibre-render-server installed and running as user '${SERVICE_USER}'."
echo ""
echo "  Status:  sudo launchctl print system/${LABEL}"
echo "  Logs:    tail -f ${LOG_DIR}/stdout.log"
echo "  Errors:  tail -f ${LOG_DIR}/stderr.log"
echo "  Stop:    sudo launchctl kill TERM system/${LABEL}"
echo "  Start:   sudo launchctl kickstart system/${LABEL}"
echo "  Remove:  sudo ./uninstall.sh"
