# Projects System — Implementation Plan

## What This Is

CLiOS is a native iOS app that connects to an OpenClaw Gateway (VPS) over WebSocket. The agent runs on the Gateway, not on-device. The app is a control surface — you steer the agent with taps and voice.

**Projects** — a new entity that groups tasks, files, and chat sessions under one umbrella. A project is like a "big task" that has sub-tasks, its own files, and dedicated chat sessions. The agent works "inside" a project — sees its tasks, reads its files, writes to its directory.

Examples: "Landing Redesign", "CRM Bot", "Weekly Reports Pipeline".

---

## Architecture Decisions (Already Made)

These decisions were made in discussion. Do not change them:

1. **Projects stored as JSON on Gateway** — same pattern as TaskService (HTTP GET for reading, WebSocket `agents.files.set` for writing)
2. **Physical isolation** — each project is a directory: `workspace/projects/{id}/` with `project.json`, `tasks/`, `files/` inside
3. **Tasks belong to exactly 1 project** — project creates its own task board. Loose tasks (no project) live in `workspace/tasks/` (existing "inbox")
4. **Hybrid sessions** — project has a default chat session created automatically. User can create additional sessions within the project. Sessions linked to projects via mapping file `projects/_sessions.json` on workspace
5. **Entities do NOT share across projects** — if a file is needed in two projects, duplicate it
6. **Agent context via system-event** — when user sends first message in a project session, app sends project context (name, description, working directory path, tasks summary)
7. **No gateway changes** — Gateway team confirmed: GET works for any path via canvas API, writing via `agents.files.set` (WebSocket), listing via `agents.files.list` (WebSocket). No native project scoping — app handles it via system-event instructions to the agent
8. **Session→Project mapping** — stored in `projects/_sessions.json` on workspace (not in gateway session metadata, because `sessions.patch` doesn't support arbitrary fields)
9. **Updates** — polling project data + agent can emit `card:notify` with project updates

---

## File System Layout on Gateway

```
workspace/
  tasks/                              # "inbox" — tasks without a project
    _index.json                       # BoardIndex (existing, unchanged)
    default.json                      # BoardFile (existing, unchanged)
  projects/
    _index.json                       # ProjectIndex — list of all projects
    _sessions.json                    # sessionKey → projectId mapping
    landing-v2/                       # one project directory
      project.json                    # project metadata
      tasks/
        _index.json                   # this project's BoardIndex
        default.json                  # default board (created with project)
      files/                          # project files (agent writes here)
    crm-bot/                          # another project
      project.json
      tasks/...
      files/...
```

---

## Data Models

### Project

```swift
struct Project: Codable, Identifiable {
    let id: String                    // slug: "landing-v2", "crm-bot"
    var name: String                  // "Landing Redesign"
    var description: String           // free-form text
    var status: ProjectStatus         // active, paused, completed, archived
    var createdAt: String             // ISO8601
    var updatedAt: String             // ISO8601
}

enum ProjectStatus: String, Codable {
    case active, paused, completed, archived
}
```

### ProjectIndex

```swift
struct ProjectIndex: Codable {
    var projects: [ProjectIndexEntry]
}

struct ProjectIndexEntry: Codable, Identifiable {
    let id: String                    // same as Project.id
    var name: String
    var status: String                // "active", "completed", etc.
    var createdAt: String
}
```

### SessionMapping

```swift
struct SessionMapping: Codable {
    var sessions: [String: String]    // sessionKey → projectId
}
```

---

## Implementation Steps

> **IMPORTANT for the implementing agent:**
> Before writing any code in a step, FIRST read the existing files mentioned in "Look at" sections. Match the patterns, naming conventions, and style of the existing code. Do not invent new patterns — follow what's already there.

---

### Step 1: Understand existing patterns

**Goal:** Understand how TaskService and TaskBoard work, because ProjectService will follow the exact same pattern.

**Look at:**
- `CliOS/CliOS/Services/TaskService.swift` — how it reads/writes JSON via Gateway. Note: it currently uses HTTP PUT for writing, but Gateway team says PUT returns 405. Check if `agents.files.set` WebSocket method exists in GatewayService. If TaskService uses HTTP PUT and it works, follow the same pattern. If not, use WebSocket write.
- `CliOS/CliOS/Services/GatewayService.swift` — find `sendRequest(method:params:)`. Find how `agents.files.list` is called. Search for `agents.files.set` or any file write method.
- `CliOS/CliOS/Services/GatewayProtocol.swift` — WebSocket frame format
- `CliOS/CliOS/Models/AgentTask.swift` — model pattern (struct, Codable, Identifiable)
- `CliOS/CliOS/Services/EntityProviders.swift` — how TaskEntityProvider fetches data. ProjectEntityProvider will follow the same structure.

**Decide:** How will ProjectService write files? HTTP PUT (like TaskService) or WebSocket `agents.files.set`? Use whichever method TaskService uses — they should be consistent. If you find that TaskService's PUT is broken, fix both to use WebSocket writes.

**Output:** No code yet. Just read and understand. Note the patterns.

---

### Step 2: Create Project model

**Goal:** Add the `Project`, `ProjectIndex`, `ProjectIndexEntry`, `SessionMapping` models.

**Look at:**
- `CliOS/CliOS/Models/` — see how existing models are structured. Match the style.
- `CliOS/CliOS/Models/AgentTask.swift` — reference for struct layout
- `CliOS/CliOS/Models/ServiceCard.swift` — reference for enum pattern

**Create:** `CliOS/CliOS/Models/Project.swift`

Contents:
- `Project` struct (id, name, description, status, createdAt, updatedAt)
- `ProjectStatus` enum (active, paused, completed, archived)
- `ProjectIndex` struct (projects array)
- `ProjectIndexEntry` struct (id, name, status, createdAt)
- `SessionMapping` struct (sessions dict: sessionKey → projectId)

Follow existing model conventions: structs, `Codable`, `Identifiable`, no optionals unless truly optional.

---

### Step 3: Create ProjectService

**Goal:** Service that reads/writes project data on Gateway. Same role as TaskService but for projects.

**Look at:**
- `CliOS/CliOS/Services/TaskService.swift` — copy this pattern exactly. ProjectService should look structurally identical.

**Create:** `CliOS/CliOS/Services/ProjectService.swift`

**Core methods:**

```
Read:
- fetchProjectIndex() -> ProjectIndex
- fetchProject(id:) -> Project
- fetchProjectTasks(projectId:, file:) -> BoardFile
- fetchSessionMapping() -> SessionMapping

Write:
- saveProject(id:, project:)
- saveProjectIndex(_:)
- saveProjectTasks(projectId:, file:, board:)
- saveSessionMapping(_:)

High-level operations:
- createProject(id:, name:, description:) -> Project
  // Creates: projects/{id}/project.json, projects/{id}/tasks/_index.json,
  //          projects/{id}/tasks/default.json (empty board with standard statuses),
  //          updates projects/_index.json
- deleteProject(id:)
  // Removes from index. Does NOT delete files on workspace (too dangerous).
  // Sets status to "archived" in project.json instead.
- listProjects() -> [Project]
  // Fetch index, then fetch each project.json for full data
```

**Path construction:**
- Base path: `projects/`
- Project index: `projects/_index.json`
- Session mapping: `projects/_sessions.json`
- Project metadata: `projects/{id}/project.json`
- Project task index: `projects/{id}/tasks/_index.json`
- Project task board: `projects/{id}/tasks/{file}`
- Project files: `projects/{id}/files/` (listing only, via agents.files.list)

**How to construct URLs:** Look at how TaskService builds its `baseURL` from `gatewayBaseURL`. Do the same, but with path `/__openclaw__/canvas/projects/` instead of `/__openclaw__/canvas/tasks/`.

**Initialization:** ProjectService needs `gatewayBaseURL` and `token`, same as TaskService. Look at where TaskService is instantiated (likely in GatewayService or a ViewModel) and follow the same pattern.

---

### Step 4: Session→Project mapping

**Goal:** Link chat sessions to projects. When user opens a project, they see only its sessions.

**Look at:**
- `CliOS/CliOS/Services/SessionStore.swift` — how sessions are managed, `currentSessionKey`, `openSession()`, `ensureSession()`
- `CliOS/CliOS/Models/ChatSession.swift` — session model

**Modify `SessionStore`:**

Add:
- `private var sessionMapping: SessionMapping` — cached mapping loaded from workspace
- `func loadSessionMapping()` — fetch `projects/_sessions.json` via ProjectService
- `func projectId(for sessionKey: String) -> String?` — lookup from cached mapping
- `func linkSession(_ sessionKey: String, to projectId: String)` — update mapping, save to workspace
- `func unlinkSession(_ sessionKey: String)` — remove from mapping
- `func sessions(for projectId: String) -> [ChatSession]` — filter `sessions` array by projectId using mapping

**When to load mapping:** After gateway connection, same time as `loadSessions()`. Look at where `loadSessions()` is called from GatewayService and add `loadSessionMapping()` next to it.

**When to save mapping:** After `linkSession` / `unlinkSession`. Write to workspace via ProjectService.

---

### Step 5: Project context in system-event

**Goal:** When user sends a message in a project-scoped session, the agent receives project context so it knows where to work.

**Look at:**
- `CliOS/CliOS/Services/GatewayService.swift` — search for `system-event` or `sendSystemEvent` or `cardCapabilityPrompt`. Find where card capabilities are sent at start of session. The project context should be appended to this same mechanism.
- Find how `sendMessage` works and where it prepends the card capability prompt.

**Modify:**

In the place where card capabilities are sent (first message in session), check if the current session is linked to a project (via `sessionStore.projectId(for: sessionKey)`). If yes, append project context:

```
Project context:
- Name: {project.name}
- Description: {project.description}
- Working directory: workspace/projects/{project.id}/
- Tasks: workspace/projects/{project.id}/tasks/
- Files: workspace/projects/{project.id}/files/
- All file operations should be relative to this working directory.
```

Fetch the project data via `ProjectService.fetchProject(id:)` to get the name and description. This is an async call — look at how the card capability prompt is built and follow the same async pattern.

---

### Step 6: EntityType .project + ProjectEntityProvider

**Goal:** Projects appear in the unified entity search (command palette).

**Look at:**
- `CliOS/CliOS/Models/EntityItem.swift` — `EntityType` enum. Add `.project` case.
- `CliOS/CliOS/Services/EntityProviders.swift` — existing providers (TaskEntityProvider, SessionEntityProvider, etc.). Follow their exact pattern.

**Modify `EntityItem.swift`:**
- Add `case project` to `EntityType`
- Add label: "Projects", icon: "folder.fill", tint: .green (or pick a color that doesn't clash — look at existing type colors)

**Add to `EntityProviders.swift`:**

```swift
class ProjectEntityProvider: EntityProvider {
    func fetchEntities() async throws -> [EntityItem] {
        // Fetch project index via ProjectService
        // Map each ProjectIndexEntry to EntityItem:
        //   id: "project:{project.id}"
        //   type: .project
        //   name: project.name
        //   path: "projects/{project.id}/"
        //   subtitle: project.status
        //   icon: from EntityType
    }
}
```

**Register provider:**
- In `GatewayService.setupEntityIndex()`, add: `index.register(provider: ProjectEntityProvider(), for: .project)`

---

### Step 7: Project creation UI

**Goal:** Sheet for creating a new project (like NewTaskSheet for tasks).

**Look at:**
- `CliOS/CliOS/Views/Workspace/NewTaskSheet.swift` — reference for form layout, style, dismiss pattern
- `CliOS/CliOS/Theme.swift` — use Theme constants for all colors/fonts/spacing

**Create:** `CliOS/CliOS/Views/Projects/NewProjectSheet.swift`

**Fields:**
- Name (required, text field)
- Description (optional, multiline text)
- Status defaults to `.active`

**On save:**
- Generate id from name (slugify: lowercase, replace spaces with hyphens, remove special chars)
- Call `ProjectService.createProject(id:name:description:)`
- Optionally create a default session linked to this project
- Dismiss sheet

**Where to present:** Look at how NewTaskSheet is presented. Follow the same pattern — likely a `.sheet()` modifier on a parent view, triggered by a button.

---

### Step 8: Project list / selection UI

**Goal:** User can see all projects and select one to open.

**Look at:**
- `CliOS/CliOS/Views/Workspace/TaskBoardView.swift` or `TaskListView.swift` — reference for list layout
- How task boards are displayed and selected

**Create:** `CliOS/CliOS/Views/Projects/ProjectListView.swift`

**Features:**
- List of projects (name, status badge, task progress summary)
- Tap → open project detail (shows its tasks, files, sessions)
- "+" button → NewProjectSheet
- Pull to refresh

**Project detail view (optional, can be simple for now):**
- Project name + description at top
- Tabs or sections: Tasks, Files, Sessions
- Tasks section → reuses existing TaskBoardView/TaskListView but scoped to project's tasks
- Files section → reuses existing file browser but scoped to `projects/{id}/files/`
- Sessions section → filtered list of sessions linked to this project

---

### Step 9: "Start chat in project context"

**Goal:** When starting a new chat, user can optionally select a project. The session gets linked and receives project context.

**Look at:**
- How new chat sessions are created. Find where the "New Chat" action is. Look in `ChatListView.swift` or `MainTabView.swift`.
- `SessionStore.ensureSession()` — how sessions are created

**Modify the new chat flow:**
- Add optional project picker (list of active projects, or "None" for standalone chat)
- If project selected:
  1. Create session as usual
  2. Call `sessionStore.linkSession(sessionKey, to: projectId)`
  3. Project context will be sent automatically on first message (Step 5)

**In ChatListView (or wherever sessions are listed):**
- Show project badge/label on sessions that belong to a project
- Optional: group sessions by project

---

### Step 10: Project dashboard card

**Goal:** Card component showing project summary for dashboard.

**Look at:**
- `CliOS/CliOS/Components/ActiveTasksCard.swift` — dashboard card pattern
- `CliOS/CliOS/Components/UsageCard.swift` — another card example
- How dashboard cards are used in `DashboardMockView.swift` or similar

**Create:** `CliOS/CliOS/Components/Cards/ProjectCard.swift`

**Shows:**
- Project name
- Status badge (active/paused/completed)
- Task progress: "5/12 tasks done" with progress bar
- Last activity timestamp
- Tap → open project detail

**Data:** Fetched via ProjectService — load project + its task board to count done/total.

---

### Step 11: Wire everything together

**Look at:**
- `CliOS/CliOS/MainTabView.swift` — where tabs are defined
- `CliOS/CliOS/CLiOSApp.swift` — app entry point, environment objects

**Integration points:**

1. **Navigation:** Projects don't add a new tab. They integrate into existing structure:
   - Chat tab: sessions show project badge, "new chat" has project picker
   - Tasks tab: can filter by project or show "inbox" (no project)
   - Dashboard: project cards

2. **GatewayService:** Initialize ProjectService when gateway connects (same place TaskService is set up). Store reference so views can access it.

3. **EntityIndex:** ProjectEntityProvider registered in `setupEntityIndex()` (Step 6).

4. **SessionStore:** Session mapping loaded on connect (Step 4).

---

### Step 12: Testing & verification

**Verify each step:**
1. App builds without errors after each step (`xcodebuild build`)
2. Project model encodes/decodes correctly (create a mock and test JSON round-trip)
3. ProjectService can read/write to workspace (test against running gateway)
4. Session mapping persists correctly
5. New project creates full directory structure on workspace
6. Project context appears in agent's system-event
7. Entity search shows projects
8. UI renders project list, creation sheet, dashboard card

---

## Card Types (Future)

When projects are working, the agent can emit structured cards:

```
[card:project.summary]
name: Landing Redesign
status: active
tasks_done: 5
tasks_total: 12
last_activity: 2026-04-10T14:30:00Z
[/card]

[card:project.created]
name: CRM Bot
id: crm-bot
[/card]
```

Add these to `CardType` enum in `ServiceCard.swift` when needed. Not required for initial implementation.

---

## Key Patterns Reference

These are the files to reference most often during implementation:

| Pattern | Reference File |
|---------|---------------|
| Data model | `Models/AgentTask.swift` |
| Service (HTTP + WS) | `Services/TaskService.swift` |
| Entity provider | `Services/EntityProviders.swift` (TaskEntityProvider) |
| Entity type | `Models/EntityItem.swift` (EntityType enum) |
| Dashboard card | `Components/ActiveTasksCard.swift` |
| Form sheet | `Views/Workspace/NewTaskSheet.swift` |
| List view | `Views/Workspace/TaskBoardView.swift` |
| System event | `Services/GatewayService.swift` (search "system-event") |
| Session management | `Services/SessionStore.swift` |
| Theme constants | `Theme.swift` |
