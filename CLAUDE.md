# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

CLiOS is a native iOS command center for OpenClaw AI agents. Not a chat app — a control surface where your agent works and you steer with taps and voice. The phone connects to an OpenClaw Gateway (VPS/Mac) over WebSocket; the agent runs on the Gateway, not on-device.

## Build & Run

This is a standard Xcode SwiftUI project. No package managers (SPM/CocoaPods) currently.

```bash
# Open in Xcode
open CliOS/CliOS.xcodeproj

# Build from CLI
xcodebuild -project CliOS/CliOS.xcodeproj -scheme CliOS -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project CliOS/CliOS.xcodeproj -scheme CliOS -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test
```

- Deployment target: iOS 17.0
- Swift 5.0, SwiftUI
- Bundle ID: `com.clios.app`
- Dark mode only (`preferredColorScheme(.dark)`)

## Architecture

```
iPhone App <--WebSocket (port 18789)--> OpenClaw Gateway <--> AI Providers
```

### Core flow
1. **Pairing**: User scans QR code → app gets gateway URL + bootstrap token → stored in Keychain → one-time process
2. **Communication**: All data flows through `GatewayService` (singleton, `@MainActor`, `ObservableObject`) via WebSocket JSON frames
3. **Rendering**: Agent streams `event:agent` frames → app renders incrementally; structured output uses the Card Protocol

### GatewayService is the central hub
`GatewayService.shared` owns all state: connection status, messages, tasks, cron jobs. Views access it via `@EnvironmentObject`. It uses `URLSessionWebSocketTask` for the WebSocket connection.

### Card Protocol
Agent output can contain structured cards — parsed from markdown codeblocks with `card:type` syntax (e.g., `[card:github.pr]...[/card]`). `CardParser` extracts these into `ServiceCard` models with typed `CardType` enum and key-value fields. Unsupported card types fall back to `.unknown` and render as text.

### Navigation
`MainTabView` has 4 tabs: Chat, Tasks, Dashboard, Settings. If not paired, app shows `PairingView` instead.

### Key layers
- **Models/**: Data types (`Message`, `AgentTask`, `CronJob`, `GatewayStatus`, `ServiceCard`) — all `Codable` + `Identifiable`
- **Services/**: `GatewayService` (WebSocket + state), `CardParser` (structured output parsing), `KeychainService` (token storage)
- **Views/**: SwiftUI views organized by tab (Chat/, Dashboard/, Settings/, Tasks/)
- **Components/**: Reusable card components (`ActiveTasksCard`, `QuickActionsGrid`, `UsageCard`)
- **Theme.swift**: All colors, typography, spacing constants. Accent color is `#FF4D00` (orange).

## Design Conventions

- Use `Theme.*` constants for all colors, fonts, and spacing — never hardcode values
- All models are structs conforming to `Identifiable` and `Codable`
- `GatewayService` is the single source of truth; don't create parallel state stores
- Card types follow `service.subtype` naming (e.g., `github.pr`, `email.draft`)

## Docs

Design docs live in `docs/` — read these before making architectural decisions:
- `ARCHITECTURE.md` — WebSocket protocol, pairing flow, frame format
- `CARD-PROTOCOL.md` — card parsing format and capability negotiation
- `FEATURES.md` — full feature set with priorities
- `MVP.md` — phased build plan
- `SERVICE-CARDS.md` — all supported card types and their fields
- `VISION.md` — product philosophy and principles
