# maplibre-render-server

A Vapor-based macOS web server that renders MapLibre maps to PNG images by spawning
`mbgl-render` subprocesses. Each request gets its own process, so renders run
concurrently without coordination overhead.

## Prerequisites

Build `mbgl-render` from [maplibre-native](https://github.com/maplibre/maplibre-native)
and place the binary somewhere accessible:

```bash
# Default expected path:
/usr/local/bin/mbgl-render

# Or set env var to a custom path:
export MBGL_RENDER_PATH=/path/to/mbgl-render
```

## API

### `POST /render`

**Query parameters:**

| Param        | Type   | Description                                        |
|--------------|--------|----------------------------------------------------|
| `centerLon`  | Double | Longitude of map center                            |
| `centerLat`  | Double | Latitude of map center                             |
| `zoom`       | Double | Zoom level (0–22)                                  |
| `width`      | Int    | Output width in points                             |
| `height`     | Int    | Output height in points                            |
| `pixelRatio` | Double | Pixel ratio — output is width×ratio × height×ratio |

**Body:** MapLibre style JSON (`Content-Type: application/json`)

**Response:** PNG image (`Content-Type: image/png`)

### Example

```bash
curl -X POST \
  "http://localhost:8080/render?centerLon=10.74&centerLat=59.91&zoom=12&width=512&height=512&pixelRatio=2" \
  -H "Content-Type: application/json" \
  -d @my-style.json \
  --output map.png
```

## Running (development)

```bash
swift run
# or with a custom mbgl-render path:
MBGL_RENDER_PATH=/opt/local/bin/mbgl-render swift run
```

Server listens on port 8080.

## Installing as a system daemon (macOS)

For production use — starts at boot, runs when no user is logged in,
restarts automatically on crash — install it as a **launchd LaunchDaemon**.

```bash
sudo ./install.sh
```

This will:
1. Create a dedicated least-privilege system user and group (`_maplibre`)
2. Build the release binary (`swift build -c release`)
3. Install it to `/usr/local/bin/maplibre-render-server`
4. Create `/var/log/maplibre-render-server/` owned by `_maplibre`
5. Install the plist to `/Library/LaunchDaemons/`
6. Bootstrap (start) the daemon immediately

### Dedicated system user (`_maplibre`)

The server runs as `_maplibre` — a hidden system account with no login shell
and no home directory. This limits what the process can access if something
goes wrong:

- Cannot log in interactively (`UserShell: /usr/bin/false`)
- No home directory (`NFSHomeDirectory: /var/empty`)
- Hidden from the login window (`IsHidden: 1`)
- Assigned a UID/GID in the system range (300–499)
- Only has write access to `/tmp` (temp files) and `/var/log/maplibre-render-server` (logs)

This follows the same convention Apple uses for its own system services
(e.g. `_www`, `_locationd`, `_spotlight`).

### Managing the daemon

```bash
# Status
sudo launchctl print system/com.halset.maplibre-render-server

# Stop
sudo launchctl kill TERM system/com.halset.maplibre-render-server

# Start
sudo launchctl kickstart system/com.halset.maplibre-render-server

# Follow logs
tail -f /var/log/maplibre-render-server/stdout.log
tail -f /var/log/maplibre-render-server/stderr.log
```

### Upgrading

Re-run `sudo ./install.sh` — it unloads the running daemon, replaces the
binary, and reloads automatically. The `_maplibre` user is left in place.

### Uninstalling

```bash
sudo ./uninstall.sh
```

The script stops the daemon, removes the binary and plist, and asks whether
to also delete the `_maplibre` user and group.

## How it works

1. Incoming style JSON is written to a temp file.
2. `mbgl-render` is spawned with the render parameters.
3. `mbgl-render` writes the PNG to another temp file.
4. Server reads the PNG and streams it back to the client.
5. Temp files are cleaned up regardless of success or failure.

Because each render is a separate OS process, concurrent requests naturally
run in parallel — limited only by the machine's CPU/GPU capacity.
