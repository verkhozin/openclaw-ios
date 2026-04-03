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

### Persistence
`ChatDatabase` (SQLite via raw `sqlite3` C API, WAL mode) stores chat sessions and messages locally. `SessionStore` manages session lifecycle. `ContentParser` extracts tags/metadata from messages at receive time for indexed storage.

### Metal Shaders
`MetalShaderView` wraps `MTKView` for GPU-rendered backgrounds. Shader source files live in `Shaders/` (`.metal` files). `ShaderSources.swift` registers available shaders; `ShaderTypes.h` defines the uniform struct layout. The `ShaderPlaygroundView` in Settings lets you preview them.

### FluidGradient
`Components/FluidGradient/` is a self-contained CoreAnimation blob gradient system (not Metal). Uses `CALayer` subclasses (`BlobLayer`, `ResizableLayer`) for animated gradient backgrounds.

### Key layers
- **Models/**: Data types (`Message`, `AgentTask`, `CronJob`, `GatewayStatus`, `ServiceCard`, `ChatSession`, `ContentBlock`, `AgentEvent`, `CachedMessage`) — all `Codable` + `Identifiable`
- **Services/**: `GatewayService` (WebSocket + state), `ChatDatabase` (SQLite persistence), `CardParser` + `ContentParser` + `MessageParser` (parsing pipeline), `KeychainService` + `DeviceCrypto` (security), `SessionStore`, `MetalShaderView` + `ShaderSources`
- **Views/**: SwiftUI views organized by tab (Chat/, Dashboard/, Settings/, Tasks/) plus Dev/ gallery views for component previews
- **Components/**: Dashboard cards (`ActiveTasksCard`, `QuickActionsGrid`, `UsageCard`), service card renderers in `Cards/` (GitHub PR, Email, Calendar, Aurora, Task, Checklist), `FluidGradient/`, `BeamAvatar`, `FolderView`
- **Shaders/**: Metal fragment shaders for animated backgrounds (aurora, sky, plasma, rain, clouds, etc.)
- **Theme.swift**: All colors, typography, spacing constants. Accent color is `#FF4D00` (orange). Named colors (bg, surface, textPrimary, etc.) are defined in the asset catalog for adaptive light/dark.

## Design Conventions

- Use `Theme.*` constants for all colors, fonts, and spacing — never hardcode values
- Use `.system()` font APIs, not `.custom()` — no custom font files for body text
- All models are structs conforming to `Identifiable` and `Codable`
- `GatewayService` is the single source of truth; don't create parallel state stores
- Card types follow `service.subtype` naming (e.g., `github.pr`, `email.draft`)
- Agent messages render as white cards on gray background; user messages are accent-colored
- Singletons (`GatewayService.shared`, `ChatDatabase.shared`, `SessionStore.shared`) — access via `.shared`, don't instantiate
- `nonisolated(unsafe)` is used on `GatewayService` connection properties that need fast-path access off MainActor; only write them on MainActor
- URL scheme: `clios://connect?host=X&port=Y&token=Z` for deep-link pairing

## Docs

Design docs live in `docs/` — read these before making architectural decisions:
- `ARCHITECTURE.md` — WebSocket protocol, pairing flow, frame format
- `CARD-PROTOCOL.md` — card parsing format and capability negotiation
- `CONNECTION-PROTOCOL.md` — device pairing flow and auto-setup
- `COMMANDS.md` — command definitions
- `FEATURES.md` / `FEATURES-V2.md` — feature set with priorities and V2 roadmap
- `MVP.md` — phased build plan
- `SERVICE-CARDS.md` / `CARD-COMPONENTS.md` — card types, fields, and component specs
- `VISION.md` — product philosophy and principles
