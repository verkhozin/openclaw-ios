# GitHub Cards — CLiOS Design Spec

Карточки рендерятся нативно в SwiftUI. Данные передаются в codeblock-формате.
Принцип: критичное — сразу, вторичное — по тапу/свайпу.

---

## Формат codeblock

```
```card:<type>
key: value
key2: value2
---
actions: action1, action2
```
```

Разделитель `---` отделяет поля от списка actions.

---

## github.pr — Pull Request

### Что критично на мобилке
- Статус (open / draft / merged / closed)
- Название PR — главный текст карточки
- Автор и ветка
- Флаги блокировки: conflicts, failing CI, awaiting review
- Размер изменений

### Обязательные поля

| Поле | Описание |
|------|----------|
| `id` | Номер PR (`#1234`) |
| `title` | Название |
| `status` | `open` / `draft` / `merged` / `closed` |
| `author` | GitHub username |
| `repo` | `owner/repo` |
| `branch_from` | Исходная ветка |
| `branch_into` | Целевая ветка |
| `url` | Ссылка на PR |

### Опциональные поля

| Поле | Описание |
|------|----------|
| `assignees` | Через запятую |
| `reviewers` | Через запятую, с суффиксом `:approved`/`:requested`/`:changes` |
| `labels` | Через запятую |
| `ci_status` | `passing` / `failing` / `pending` / `skipped` |
| `conflicts` | `true` / `false` |
| `additions` | Число добавленных строк |
| `deletions` | Число удалённых строк |
| `files_changed` | Число изменённых файлов |
| `comments` | Число комментариев |
| `created_at` | ISO 8601 |
| `updated_at` | ISO 8601 |
| `milestone` | Название milestone |
| `draft` | `true` / `false` (дублирует status=draft, удобно для логики) |
| `mergeable` | `true` / `false` / `unknown` |
| `body_preview` | Первые ~150 символов описания |

### Визуальное оформление

**Статус-бейдж (цвет фона + текст):**
- `open` — зелёный
- `draft` — серый
- `merged` — фиолетовый
- `closed` — красный

**Иконки-флаги (строка под заголовком):**
- CI failing — красный кружок с крестом
- CI passing — зелёный кружок с галкой
- Conflicts — жёлтый треугольник с восклицательным знаком
- Awaiting review — часы (серые)
- Changes requested — красный круговой значок

**Дифф-строка:** `+{additions} -{deletions}` малым шрифтом, зелёный/красный

**Reviewers:** аватарки + цветная обводка (зел = approved, красн = changes requested, серая = requested)

**Размер:** S / M / L / XL бейдж по числу изменённых строк
- S: <50, M: 50-200, L: 200-500, XL: 500+

### Actions

| Action | Тип | Условие показа |
|--------|-----|---------------|
| `approve` | Кнопка | Ты reviewer, ещё не одобрил |
| `request_changes` | Кнопка | Ты reviewer |
| `merge` | Кнопка | Ты можешь мержить, CI passing, no conflicts |
| `comment` | Кнопка | Всегда |
| `open` | Свайп вправо | Всегда — открыть в Safari |
| `checkout` | Кнопка | Опционально, если есть CLI-интеграция |
| `close` | Деструктивный свайп влево | Автор или maintainer |

### Пример карточки

```card:github.pr
id: 1847
title: feat: add swipe actions to card renderer
status: open
author: alexkorolev
repo: openclaw/clios
branch_from: feature/card-swipe
branch_into: main
ci_status: passing
conflicts: false
reviewers: masha:approved, petrov:requested
additions: 312
deletions: 47
files_changed: 8
comments: 4
labels: enhancement, ios
updated_at: 2026-03-28T18:22:00Z
body_preview: Implements swipe-right to approve and swipe-left to close on all card types. Tested on iPhone 15 Pro and iPad.
url: https://github.com/openclaw/clios/pull/1847
---
actions: approve, comment, merge, open
```

---

## github.issue — Issue

### Что критично на мобилке
- Открыто/закрыто
- Название
- Кто назначен (если назначен на тебя — подсветить)
- Приоритет/лейблы (bug vs feature)
- Есть ли активность

### Обязательные поля

| Поле | Описание |
|------|----------|
| `id` | Номер (`#567`) |
| `title` | Название |
| `status` | `open` / `closed` |
| `author` | GitHub username |
| `repo` | `owner/repo` |
| `url` | Ссылка |

### Опциональные поля

| Поле | Описание |
|------|----------|
| `assignees` | Через запятую |
| `labels` | Через запятую |
| `milestone` | Название |
| `comments` | Число |
| `body_preview` | ~150 символов |
| `created_at` | ISO 8601 |
| `updated_at` | ISO 8601 |
| `linked_pr` | Номер связанного PR |
| `reactions` | `thumbsup:12, heart:3` |
| `state_reason` | `completed` / `not_planned` (при status=closed) |

### Визуальное оформление

**Статус-бейдж:**
- `open` — зелёный
- `closed / completed` — серо-фиолетовый
- `closed / not_planned` — серый, перечёркнутый стиль

**Лейблы:** цветные таблетки (цвет из GitHub API, hex), ограничить до 3 видимых + "+N"

**Назначен на тебя:** выделение карточки синей левой полосой

**Комментарии:** иконка речевого пузыря + число

**Linked PR:** маленький бейдж "PR #N" с цветом по статусу PR

### Actions

| Action | Тип | Условие |
|--------|-----|---------|
| `comment` | Кнопка | Всегда |
| `assign_me` | Кнопка | Не назначен на тебя |
| `close` | Деструктивный свайп | Автор или maintainer |
| `open` | Свайп вправо | Всегда |
| `label` | Кнопка (шит) | Maintainer |

### Пример карточки

```card:github.issue
id: 2103
title: Card footer overlaps safe area on iPhone SE
status: open
author: testuser_qa
repo: openclaw/clios
assignees: alexkorolev
labels: bug, ui, priority:high
comments: 7
linked_pr: 1847
body_preview: On iPhone SE (1st gen) the action buttons in card footer are partially hidden behind the home indicator area. Reproducible 100%.
updated_at: 2026-03-27T14:05:00Z
url: https://github.com/openclaw/clios/issues/2103
---
actions: comment, open, close
```

---

## github.ci — CI/CD Run

### Что критично на мобилке
- Упало или прошло — главный вопрос
- Какой workflow / ветка / коммит
- Какой шаг упал
- Сколько времени выполнялось

### Обязательные поля

| Поле | Описание |
|------|----------|
| `run_id` | ID запуска |
| `workflow` | Название workflow |
| `status` | `success` / `failure` / `cancelled` / `in_progress` / `queued` |
| `repo` | `owner/repo` |
| `branch` | Ветка |
| `commit_sha` | Короткий SHA (7 символов) |
| `url` | Ссылка на run |

### Опциональные поля

| Поле | Описание |
|------|----------|
| `commit_message` | Первая строка коммит-сообщения |
| `triggered_by` | Username или `push` / `pull_request` / `schedule` |
| `duration_sec` | Длительность в секундах |
| `failed_step` | Название упавшего шага |
| `failed_job` | Название упавшей job |
| `jobs_total` | Всего job |
| `jobs_passed` | Прошло job |
| `started_at` | ISO 8601 |
| `pr_number` | Если запуск привязан к PR |

### Визуальное оформление

**Статус — крупная иконка + цвет фона шапки карточки:**
- `success` — зелёный фон/иконка
- `failure` — красный
- `in_progress` — синий с анимацией вращения
- `queued` — серый
- `cancelled` — серый, зачёркнутый стиль

**Прогресс jobs:** `passed/total` с маленькими точками-индикаторами

**Failed step:** красный блок с именем шага — самое важное при failure

**Duration:** человекочитаемо — "2m 34s"

**Triggered by:** маленький текст под веткой

### Actions

| Action | Тип | Условие |
|--------|-----|---------|
| `rerun` | Кнопка | status=failure или cancelled |
| `rerun_failed` | Кнопка | status=failure, есть failed jobs |
| `cancel` | Деструктивная | status=in_progress или queued |
| `open_logs` | Свайп / кнопка | Всегда |
| `open` | Свайп вправо | Всегда |

### Пример карточки

```card:github.ci
run_id: 8472910
workflow: iOS Build & Test
status: failure
repo: openclaw/clios
branch: feature/card-swipe
commit_sha: a3f8c21
commit_message: feat: add swipe actions to card renderer
triggered_by: alexkorolev
duration_sec: 187
failed_job: test
failed_step: Run unit tests
jobs_total: 3
jobs_passed: 2
started_at: 2026-03-28T17:45:00Z
pr_number: 1847
url: https://github.com/openclaw/clios/actions/runs/8472910
---
actions: rerun_failed, open_logs, open
```

---

## github.commit — Commit

### Что критично на мобилке
- Сообщение коммита
- Автор и время
- В какую ветку / на каком PR
- Размер изменений

### Обязательные поля

| Поле | Описание |
|------|----------|
| `sha` | Полный SHA (отображать 7) |
| `message` | Первая строка сообщения |
| `author` | GitHub username или имя |
| `repo` | `owner/repo` |
| `branch` | Ветка |
| `url` | Ссылка |

### Опциональные поля

| Поле | Описание |
|------|----------|
| `author_email` | Email автора |
| `committed_at` | ISO 8601 |
| `additions` | Строки |
| `deletions` | Строки |
| `files_changed` | Число |
| `message_body` | Расширенное описание |
| `pr_number` | Связанный PR |
| `ci_status` | `passing` / `failing` / `pending` |
| `verified` | `true` / `false` (GPG-подпись) |
| `co_authors` | Через запятую |

### Визуальное оформление

**SHA:** моноширинный шрифт, серый, 7 символов, тапабельный (copy)

**Дифф:** `+{additions} -{deletions}` зелёный/красный

**CI бейдж:** маленький цветной кружок рядом с SHA

**Verified:** маленький бейдж с замком (зелёный)

**Время:** относительное ("3 hours ago"), полное при тапе

**Ветка:** таблетка с иконкой ветки

### Actions

| Action | Тип | Условие |
|--------|-----|---------|
| `copy_sha` | Свайп / долгий тап | Всегда |
| `open` | Кнопка / свайп вправо | Всегда |
| `open_diff` | Кнопка | Всегда |
| `revert` | Деструктивный свайп | Maintainer |
| `cherry_pick` | Кнопка | Опционально |

### Пример карточки

```card:github.commit
sha: a3f8c217b94e1d2c5f0e3a8b7c6d4e9f1a2b3c4d
message: feat: add swipe actions to card renderer
author: alexkorolev
repo: openclaw/clios
branch: feature/card-swipe
committed_at: 2026-03-28T17:40:00Z
additions: 312
deletions: 47
files_changed: 8
pr_number: 1847
ci_status: failing
verified: true
url: https://github.com/openclaw/clios/commit/a3f8c21
---
actions: open_diff, open, copy_sha
```

---

## github.review — Code Review

### Что критично на мобилке
- Кто просит ревью / чей результат
- Какой PR
- Решение (approved / changes requested / commented)
- Комментарии к конкретным строкам — краткий preview

### Обязательные поля

| Поле | Описание |
|------|----------|
| `pr_id` | Номер PR |
| `pr_title` | Название PR |
| `repo` | `owner/repo` |
| `type` | `requested` / `submitted` |
| `url` | Ссылка на PR |

### Поля для type=requested

| Поле | Описание |
|------|----------|
| `requested_from` | Кто запрашивает (автор PR) |
| `requested_at` | ISO 8601 |

### Поля для type=submitted

| Поле | Описание |
|------|----------|
| `reviewer` | Кто сделал ревью |
| `decision` | `approved` / `changes_requested` / `commented` / `dismissed` |
| `submitted_at` | ISO 8601 |
| `comment_count` | Число review-комментариев |
| `body_preview` | ~150 символов общего комментария |

### Опциональные поля

| Поле | Описание |
|------|----------|
| `pr_branch` | Ветка PR |
| `pr_author` | Автор PR |
| `pr_ci_status` | Статус CI на PR |
| `inline_comments` | Число inline-комментариев |

### Визуальное оформление

**type=requested — карточка-призыв к действию:**
- Заголовок крупный: "Review requested"
- PR title как основной текст
- Кнопки approve / request changes сразу видны

**type=submitted — карточка-результат:**

Decision бейдж:
- `approved` — зелёный с галкой
- `changes_requested` — красный с X
- `commented` — серый
- `dismissed` — серый, зачёркнутый

**Число комментариев:** иконка + число

**Body preview:** курсив, ограничен 2 строками

### Actions

| Action | Тип | Условие |
|--------|-----|---------|
| `approve` | Зелёная кнопка | type=requested |
| `request_changes` | Красная кнопка | type=requested |
| `comment` | Кнопка | Всегда |
| `open_pr` | Свайп вправо / кнопка | Всегда |
| `dismiss` | Свайп | type=submitted, maintainer |

### Примеры карточек

**Запрос ревью:**
```card:github.review
type: requested
pr_id: 1847
pr_title: feat: add swipe actions to card renderer
pr_author: alexkorolev
pr_branch: feature/card-swipe
repo: openclaw/clios
requested_from: alexkorolev
requested_at: 2026-03-28T17:50:00Z
pr_ci_status: failing
url: https://github.com/openclaw/clios/pull/1847
---
actions: approve, request_changes, comment, open_pr
```

**Результат ревью:**
```card:github.review
type: submitted
pr_id: 1847
pr_title: feat: add swipe actions to card renderer
repo: openclaw/clios
reviewer: masha_dev
decision: changes_requested
submitted_at: 2026-03-28T19:10:00Z
comment_count: 5
inline_comments: 3
body_preview: Overall structure looks good, but there are some concerns about memory management in the gesture recognizer. Also, the threshold values need to be configurable.
url: https://github.com/openclaw/clios/pull/1847#pullrequestreview-2049123
---
actions: comment, open_pr
```

---

## github.release — Release

### Что критично на мобилке
- Версия и название
- Черновик или опубликован
- Pre-release или стабильный
- Дата
- Краткий changelog (первые N пунктов)

### Обязательные поля

| Поле | Описание |
|------|----------|
| `tag` | Тег (`v1.4.0`) |
| `repo` | `owner/repo` |
| `status` | `published` / `draft` / `prerelease` |
| `url` | Ссылка |

### Опциональные поля

| Поле | Описание |
|------|----------|
| `name` | Название релиза (если отличается от тега) |
| `author` | Кто опубликовал |
| `published_at` | ISO 8601 |
| `body_preview` | Первые ~300 символов changelog |
| `assets_count` | Число прикреплённых файлов |
| `assets` | `filename:size_bytes`, через запятую |
| `target_branch` | Ветка/коммит |
| `commits_since_last` | Число коммитов с прошлого релиза |
| `contributors` | Число контрибьюторов в этом релизе |
| `reactions` | `rocket:24, heart:8` |

### Визуальное оформление

**Тег:** крупный, моноширинный шрифт, цветной (зелёный для stable, жёлтый для prerelease, серый для draft)

**Статус-бейдж:**
- `published` — зелёный "Stable"
- `prerelease` — жёлтый "Pre-release"
- `draft` — серый "Draft"

**Changelog preview:** markdown-стиль, маркированный список, первые 3-5 пунктов, остальное за "Show more"

**Assets:** маленькие таблетки с иконкой файла и размером

**Реакции:** если есть, строка с числами (rocket — популярность релиза)

### Actions

| Action | Тип | Условие |
|--------|-----|---------|
| `publish` | Зелёная кнопка | status=draft |
| `open` | Кнопка / свайп вправо | Всегда |
| `copy_tag` | Долгий тап на теге | Всегда |
| `download` | Кнопка | Есть assets |
| `edit` | Кнопка | Author или maintainer |
| `delete` | Деструктивный свайп | Author или maintainer, status=draft |

### Пример карточки

```card:github.release
tag: v1.4.0
name: Swipe Actions & Performance
repo: openclaw/clios
status: published
author: alexkorolev
published_at: 2026-03-28T20:00:00Z
body_preview: ### What's new\n- Swipe actions on all card types\n- 40% faster card rendering via async preload\n- Fixed safe area overlap on iPhone SE\n- Dark mode improvements\n\n### Breaking changes\n- Card action API: `action_id` field is now required
assets_count: 3
assets: CLiOS-1.4.0.ipa:48234567, CLiOS-1.4.0.dSYMs.zip:12048234, release-notes.txt:4096
commits_since_last: 34
contributors: 4
reactions: rocket:31, heart:12
url: https://github.com/openclaw/clios/releases/tag/v1.4.0
---
actions: open, download, copy_tag
```

---

## Общие принципы рендеринга

### Иерархия информации

1. **Первый экран карточки (collapsed):** статус, заголовок, ключевые флаги, время
2. **Expanded (тап):** все опциональные поля, preview текста, полный список actions
3. **Safari/WebView (open action):** полный контекст на github.com

### Временные метки

- До 1 минуты: "just now"
- До 1 часа: "N minutes ago"
- До 24 часов: "N hours ago"
- До 7 дней: "Mon, 15:30"
- Старше: "Mar 25"
- Полная дата при долгом тапе

### Длина текстов

- Заголовок (title): max 2 строки, затем truncate с "..."
- Body preview: max 3 строки в collapsed, полный в expanded
- Ветки/теги: max 30 символов + "..."

### Цветовая схема (системные цвета SwiftUI)

| Состояние | Цвет |
|-----------|------|
| Success / Open / Approved | `.green` |
| Failure / Closed / Changes requested | `.red` |
| In progress / Pending | `.blue` |
| Draft / Cancelled / Dismissed | `.secondary` |
| Warning / Conflicts / Pre-release | `.yellow` / `.orange` |
| Merged | `.purple` |

### Деструктивные actions

Всегда требуют подтверждения (confirmation sheet) перед выполнением:
- close issue/PR
- delete release
- cancel CI run
- revert commit

### Доступность (Accessibility)

- Все бейджи и иконки имеют `accessibilityLabel`
- Actions доступны через контекстное меню (долгий тап) — дублируют свайп
- VoiceOver зачитывает: "[тип карточки], [заголовок], [статус], [ключевые флаги]"
