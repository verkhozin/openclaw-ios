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
- [ ] **Smart Mentions — inline chips в текстовом поле**
  - [ ] **MentionTextView (UIViewRepresentable)**
    - [ ] Обёртка UITextView с NSAttributedString, замена TextField
    - [ ] Двусторонний биндинг: attributedText ↔ SwiftUI state
    - [ ] Matching стиля: font .system(16), tint, padding, cornerRadius 22 — как текущий TextField
    - [ ] Поддержка multiline (аналог axis: .vertical, lineLimit 1...6)
    - [ ] @FocusState интеграция через UITextViewDelegate becomeFirstResponder/resignFirstResponder
  - [ ] **MentionAttachment (NSTextAttachment + NSTextAttachmentViewProvider)**
    - [ ] Кастомный NSTextAttachment subclass с полями: mentionType, entityId, displayName
    - [ ] NSTextAttachmentViewProvider → loadView() возвращает UIView (chip)
    - [ ] Chip view: иконка (SF Symbol) + текст + фон (pill shape), высота = line height
    - [ ] Разные стили по типу: файл (оранжевый), чат (синий), таск (зелёный), агент (фиолетовый)
    - [ ] bounds настройка чтобы chip не ломал line spacing
  - [ ] **@ триггер и автокомплит**
    - [ ] Детект ввода `@` — запуск autocomplete режима
    - [ ] Трекинг текста после `@` до пробела/выбора (query string)
    - [ ] Popup над клавиатурой: список результатов с иконкой + название + путь
    - [ ] Категории: All / Files / Tasks / Sessions / Agents (pill tabs)
    - [ ] Fuzzy-match поиск по displayName
    - [ ] Источники: EntityIndex (FileService, TaskService, SessionStore, Gateway agents)
    - [ ] Выбор → вставка MentionAttachment в текст, удаление `@query`
    - [ ] Dismiss: пробел без выбора / backspace до `@` / tap outside
  - [ ] **Редактирование и курсор**
    - [ ] Mention как atomic unit — курсор перескакивает целиком
    - [ ] Backspace: первый — подсветить mention, второй — удалить
    - [ ] Нельзя встать курсором внутрь mention'а
    - [ ] Copy/paste: fallback в plain text (`@readme.md`)
  - [ ] **Сериализация при отправке**
    - [ ] Парсинг attributedText → plain text + массив mentions [{type, id, range}]
    - [ ] Формат в тексте: `@[type:id:displayName]` или аналог
    - [ ] Передача mentions как structured metadata в chat.send params
  - [ ] **Рендер mentions в полученных сообщениях**
    - [ ] Парсинг mention-маркеров из входящих сообщений
    - [ ] Рендер как кликабельный chip в MessageBubble
    - [ ] Tap → навигация к сущности (файл, таск, сессия)
- [ ] Wire up real latency (`gateway.status.latencyMs`) to SignalFieldRadarView instead of hardcoded value
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
  - [ ] Suppress other apps' Live Activities (Dynamic Island) when our Live Activity is active — use ImmersiveHostingController (fullscreen present with prefersStatusBarHidden + prefersHomeIndicatorAutoHidden + preferredScreenEdgesDeferringSystemGestures)
  - [ ] Connect `GatewayStatusMockView` — Signal Field Radar (gateway connection status)
  - [ ] Connect `AgentClusterMockView` — agent cluster visualization
  - [ ] Connect `GitGraphMockView` — git graph visualization
  - [ ] Connect `SubAgentMockView` — sub-agent activity visualization
- [ ] Approve/deny push actions
- [ ] Cron list with toggle + manual run

## Backlog (add when needed)

- [ ] Projects system: проект объединяет задачи + файлы + агентов под одной сущностью
  - [ ] Модель Project: name, description, linked tasks, linked files/folders, linked agents/sessions
  - [ ] Проект как контекст: открыл проект — видишь его таски, файлы, активных агентов
  - [ ] Карточка проекта на дашборде: прогресс, последняя активность, кол-во задач
  - [ ] Продумать: как проект связывается с gateway (repo? workspace? manual?)
- [ ] Git repository browser: выбор репо, переключение веток, просмотр файлов по ветке
- [ ] BranchEntityProvider: индексация веток через Gateway git API (когда появится эндпоинт)
- [ ] Gateway endpoint `/__openclaw__/entities/index?since={ts}` — серверная индексация + дельта-синк
  - [ ] Сервер индексирует файлы, таски, агентов, крон-джобы, ветки
  - [ ] Клиент переключается с per-source polling на один эндпоинт
  - [ ] Дельта-синк: отдавать только изменённые сущности с последнего запроса
- [x] ~~Smart mentions UI в ChatInputBar~~ — moved to Phase 1 as detailed block
- [ ] Link handling: clickable URLs in messages, link shortening/preview
- [ ] Cards deferred: github.issue, github.ci, github.commit, github.review, github.release, email.inbox, email.digest, email.sent, calendar.*, linear.*, task.result, task.queue, file.diff, file.saved, monitoring.*, infographics
- [ ] Personal / lifestyle карточки (агент + карточка, без отдельного UI):
  - [ ] `card:expense` — трекер расходов: сумма, категория, дата, заметка. "Потратил 500 на обед" → карточка
  - [ ] `card:expense.summary` — infographic: расходы за неделю/месяц, breakdown по категориям (ring/bar)
  - [ ] `card:habit` — трекер привычек: название, streak, сегодня выполнено/нет. Агент спрашивает вечером
  - [ ] `card:habit.board` — все привычки с streak-визуализацией (grid/heatmap)
  - [ ] `card:mood` — дневник настроения: emoji, заметка, timestamp. Агент спрашивает 1-2 раза в день
  - [ ] `card:health` — вес/сон/шаги/вода: значение, тренд, цель. Данные от агента или HealthKit
  - [ ] `card:goal` — цели: название, прогресс %, дедлайн, подзадачи
  - [ ] `card:reminder` — напоминания: текст, время, повтор. Агент ставит через cron
  - [ ] `card:note` — быстрая заметка: текст, теги, timestamp. "Запомни: паспорт в верхнем ящике"
  - [ ] `card:recipe` — рецепт: название, ингредиенты, шаги. "Что приготовить из курицы и риса?"
  - [ ] `card:travel` — путешествие: рейс, отель, даты, документы. Агент парсит из email/booking
  - [ ] `card:subscription` — подписки: сервис, сумма, дата списания, статус
  - [ ] Добавить карточку заполнения дней, как на гите. И в целом посмотреть виджеты на пинтересте - подумать что можно добавить. 
   - [ ] Добавить карточку заполнения дней, как на гите. И в целом посмотреть виджеты на пинтересте - подумать что можно добавить. То же самое для виджетов
    - [ ] Добавить карточку заполнения дней, как на гите. И в целом посмотреть виджеты на пинтересте - подумать что можно добавить. то же самое для уведомлений

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
