# Architecture

## Connection

App connects to OpenClaw Gateway via WebSocket.

```
iPhone App  <--WebSocket-->  Gateway (VPS/Mac)  <---->  AI Provider
   role: operator                port 18789              Anthropic/OpenAI/etc
```

- Protocol: WebSocket, JSON text frames
- Auth: Gateway token (obtained via QR pairing, one-time)
- Role: `operator` with scopes `operator.read` + `operator.write`
- File access: HTTP GET to `http://gateway:port/__openclaw__/canvas/...` with same token

## Pairing Flow

1. User runs `openclaw qr` on gateway host
2. App scans QR code
3. QR contains gateway URL + bootstrap token
4. App sends `connect` frame with token
5. Gateway approves device
6. Token stored in iOS Keychain
7. Done. Never ask again.

## Data Flow

**Chat:** App sends `req:agent` -> Gateway streams `event:agent` frames -> App renders incrementally

**Files:** Agent writes to workspace -> App requests via HTTP -> Renders in WebView/native

**Status:** App sends `req:health` / `req:status` -> Gateway responds with current state

**Cron:** App sends cron CRUD requests -> Gateway manages schedule

**Push:** Gateway sends APNs push via relay -> App wakes, shows notification with action buttons

## Network Access

Gateway must be reachable from phone:
- Same Wi-Fi: direct LAN (Bonjour discovery)
- Remote: Tailscale (recommended) or public URL with reverse proxy
- Fallback: manual host/port entry

## Tech Stack

- SwiftUI
- Native WebSocket (URLSessionWebSocketTask)
- WidgetKit, ActivityKit (Live Activities)
- App Intents (Siri/Shortcuts)
- EventKit (Calendar/Reminders)
- WKWebView (HTML preview)
- Keychain (token storage)
