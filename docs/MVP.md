# MVP Scope

What to build first. Ship in 2-3 weeks.

## Phase 1: Core (week 1-2)

- [x] WebSocket connection with challenge-response handshake
- [x] Ed25519 device signing (CryptoKit Curve25519)
- [x] Keychain persistence (URL, token, device keypair)
- [x] Connection test view with live log
- [ ] Pairing flow UI: статусы подключения при входе
  - [ ] "Connecting..." — открытие WebSocket
  - [ ] "Waiting for challenge..." — ожидание connect.challenge
  - [ ] "Authenticating..." — отправлен connect req, ждём ответ
  - [ ] "Awaiting approval..." — NOT_PAIRED, устройство ждёт одобрения на стороне OpenClaw
  - [ ] "Approved!" — hello-ok получен, переход на главный экран
  - [ ] "Rejected" / "Error" — с причиной и кнопкой retry
  - [ ] Polling или ожидание события approval пока оператор одобряет устройство на gateway
- [ ] QR pairing (камера → парсинг JSON → auto-pair)
- [x] Chat with streaming responses (chat.send + event:chat delta/final)
- [ ] Session management & local cache (SQLite)
  - [ ] SQLite schema: messages, sessions, client_metadata, session_metadata
  - [ ] chat.history — загрузка последних N сообщений при первом открытии сессии
  - [ ] Incremental sync: при повторном открытии — показать кэш, фоном дотянуть новое после lastSeq
  - [ ] ContentParser: парсинг при получении → parsedBlocks (text/code/card), tags, hasCode, hasCard
  - [ ] Pagination: скролл вверх → подгрузка старых сообщений из Gateway
  - [ ] Offline read: показ кэшированных сообщений без сети
  - [ ] Offline write: очередь отправки, отправка при reconnect
  - [ ] unreadCount: локальный lastReadSeq per session
  - [ ] Список сессий: сортировка по lastMessageAt из SQLite
  - [ ] Очистка кэша: сессии не открытые 30 дней
  - [ ] client_metadata (pinned, bookmarked, user tags) — отдельная таблица, не удаляется при очистке кэша
  - [ ] session_metadata (lastReadSeq, pinned, muted, customTitle, folder)
  - [ ] iCloud sync client_metadata через CloudKit (на будущее)
- [ ] Code blocks with syntax highlighting + copy
- [ ] Voice input (hold to record, speech-to-text, send as text)
- [ ] Task queue (list active/recent subagents with status)
- [ ] Push notifications (agent message, subagent done)
- [ ] Basic file preview (HTML in WebView, images inline)

## Phase 2: Native (week 3)

- [ ] Quick Actions grid (customizable buttons)
- [ ] Lock Screen widget (usage ring)
- [ ] Home Screen widget (morning card)
- [ ] Live Activity for running subagents
- [ ] Approve/deny push actions
- [ ] Cron list with toggle + manual run

## Backlog (add when needed)

- [ ] Git repository browser: выбор репо, переключение веток, просмотр файлов по ветке

- [ ] Link handling: clickable URLs in messages, link shortening/preview
- [ ] Cards deferred: github.issue, github.ci, github.commit, github.review, github.release, email.inbox, email.digest, email.sent, calendar.*, linear.*, task.result, task.queue, file.diff, file.saved, monitoring.*, infographics

## Phase 3: Integration (week 4+)

- [ ] Share Sheet extension
- [ ] Siri Shortcuts
- [ ] Calendar read/write via EventKit
- [ ] Focus mode adaptation
- [ ] Privacy dashboard
- [ ] Monitoring (usage %, token spend, gateway health)

## Phase 4: Platforms

- [ ] macOS app (Catalyst or native SwiftUI, shared codebase)
- [ ] Always-on-screen notch overlay (Dynamic Island style for Mac notch: status, quick input, agent activity)

## Non-goals for MVP

- Android (later)
- On-device LLM
- Multi-gateway switching
- Collaboration/sharing features
