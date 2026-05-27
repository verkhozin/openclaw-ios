# Contributing to CLiOS

Thanks for your interest in contributing to CLiOS!

## Getting Started

1. Fork the repository
2. Clone your fork
3. Open `CliOS/CliOS.xcodeproj` in Xcode
4. Build and run on iOS Simulator (iPhone 16, iOS 17+)

## Requirements

- Xcode 15+
- iOS 17.0 deployment target
- No external dependencies (no SPM/CocoaPods)

## Making Changes

- Create a branch from `main`
- Keep changes focused and minimal
- Match the existing code style
- Use `Theme.*` constants for colors, fonts, and spacing
- All models should conform to `Identifiable` and `Codable`

## Pull Requests

1. One PR per feature or fix
2. Write a clear description of what changed and why
3. Make sure the project builds without warnings
4. Test on iOS Simulator before submitting

## Code Style

- SwiftUI + Swift 5
- Dark mode only (`preferredColorScheme(.dark)`)
- System fonts only (`.system()`, not `.custom()`)
- Singletons accessed via `.shared` (e.g., `GatewayService.shared`)

## Architecture

CLiOS is a thin client that connects to an OpenClaw Gateway over WebSocket. The agent runs on the Gateway, not on-device. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

Key rule: `GatewayService` is the single source of truth for all state. Don't create parallel state stores.

## Reporting Issues

Open an issue with:
- What you expected
- What happened instead
- Steps to reproduce
- iOS version and device/simulator

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
