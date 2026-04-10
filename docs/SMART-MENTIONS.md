# Smart Mentions — Implementation Guide

Inline `@`-mention system for the chat input field. Users type `@` to reference files, tasks, sessions, agents — rendered as colored chips with icons directly inside the text.

## What's Already Done

### Task 1: MentionTextView (UIViewRepresentable) — DONE

Files created/modified:

- **`Components/MentionTextView.swift`** — new file
  - `MentionTextController` (`@MainActor ObservableObject`) — bridge for inserting mentions from SwiftUI. Holds `weak var textView: UITextView?`. Method `insertMention(name:icon:color:)` builds an `NSMutableAttributedString` with `NSTextAttachment` (SF Symbol icon) + colored text and inserts at cursor position.
  - `MentionTextView` (`UIViewRepresentable`) — wraps `UITextView`. Bindings: `$text` (String), `$isFocused` (Bool). Params: `textColor`, `tintColor`, `font`, `maxLines`, `controller`. Supports dynamic height (1–6 lines then scrolls), placeholder label, focus management via binding (not @FocusState).
  - Coordinator handles `UITextViewDelegate` — syncs `tv.text` → `parent.text`, manages placeholder visibility, calls `invalidateIntrinsicContentSize()` on change.

- **`Views/Chat/ChatButtonsView.swift`** — modified
  - `ChatInputOverlay` (the visible text input when composing): `TextField` replaced with `MentionTextView`. `@FocusState` changed to `@State`. Added `@StateObject mentionController` and `mockMentionIndex`.
  - `ChatButtonsView` (hidden when composing, but kept consistent): same replacement.
  - Paperclip button in `ChatInputOverlay` wired to insert mock mentions (cycles: file/chat/task/agent).

**Current state**: UITextView works as drop-in replacement. Paperclip inserts colored inline mentions (static `NSTextAttachment` with icon + colored text). Build succeeds.

---

## What Remains

### Task 2: MentionAttachment (NSTextAttachmentViewProvider)

**Goal**: Replace the current static `NSTextAttachment` + colored text approach with real UIView-based chips via `NSTextAttachmentViewProvider` (iOS 15+). This gives full control — pill backgrounds, rounded corners, animated icons, etc.

**Files to create/modify**:
- `Components/MentionChipView.swift` — new. The UIView rendered inside the text.
- `Components/MentionTextView.swift` — modify `MentionTextController.insertMention()`.

**Implementation**:

1. Create `MentionAttachment: NSTextAttachment` subclass:
   ```swift
   class MentionAttachment: NSTextAttachment {
       let mentionType: EntityType  // from Models/EntityItem.swift
       let entityId: String
       let displayName: String

       override func viewProvider(
           for parentView: UIView?,
           location: any NSTextLocation,
           textContainer: NSTextContainer?
       ) -> NSTextAttachmentViewProvider? {
           MentionChipProvider(textAttachment: self, parentView: parentView,
                               textLayoutManager: nil, location: location!)
       }
   }
   ```

2. Create `MentionChipProvider: NSTextAttachmentViewProvider`:
   ```swift
   class MentionChipProvider: NSTextAttachmentViewProvider {
       override func loadView() {
           let chip = MentionChipView(attachment: textAttachment as! MentionAttachment)
           self.view = chip
       }

       override var intrinsicSize: CGSize {
           // Measure chip width dynamically based on text, keep height = line height
       }
   }
   ```

3. Create `MentionChipView: UIView`:
   - Pill shape (rounded rect background with EntityType color at 15% opacity)
   - SF Symbol icon (tinted with EntityType color)
   - Label (EntityType color, .medium weight)
   - Height matches font line height (currently 16pt font → ~19pt line height)
   - Use `EntityType.icon` and `EntityType.tint` from `Models/EntityItem.swift` for colors/icons

4. Update `MentionTextController.insertMention()`:
   - Replace current `NSTextAttachment` + colored text approach
   - Create `MentionAttachment` instead and insert as a single attachment (the ViewProvider renders the full chip)
   - The mention is now a single character in the attributed string (the object replacement char `\u{FFFC}`)

**Style reference** — EntityType colors/icons are defined in `Models/EntityItem.swift`:
```
file    → "doc"              → .blue
task    → "checklist"        → .orange
session → "bubble.left"      → .purple
agent   → "cpu"              → .green
cron    → "clock"            → .yellow
```

**Gotcha**: `NSTextAttachmentViewProvider.intrinsicSize` must return the exact size of the chip. If it returns wrong height, line spacing breaks. Measure the UIView after layout and return the measured size. Keep chip height ≤ font line height + 4pt.

---

### Task 3: @ Trigger and Autocomplete

**Goal**: When user types `@`, show a popup above the keyboard with search results from `EntityIndex`. User selects → mention chip is inserted.

**Files to create/modify**:
- `Components/MentionPopupView.swift` — new. The autocomplete popup (SwiftUI overlay).
- `Components/MentionTextView.swift` — modify Coordinator to detect `@` and track query.
- `Views/Chat/ChatButtonsView.swift` — add popup overlay to `ChatInputOverlay`.

**Implementation**:

1. **@ Detection** — in `MentionTextView.Coordinator.textViewDidChange(_:)`:
   - After updating `parent.text`, scan backwards from cursor to find `@`
   - If found and preceded by whitespace/start-of-text: enter mention mode
   - Extract query = text between `@` and cursor position
   - Expose via new bindings: `@Binding var mentionQuery: String?` (nil = no popup)

   ```swift
   func textViewDidChange(_ tv: UITextView) {
       parent.text = tv.text
       updatePlaceholder(tv)
       tv.invalidateIntrinsicContentSize()
       detectMentionTrigger(in: tv)  // NEW
   }

   private func detectMentionTrigger(in tv: UITextView) {
       let text = tv.text ?? ""
       let cursor = tv.selectedRange.location
       guard cursor > 0 else { parent.mentionQuery = nil; return }

       // Walk backwards from cursor to find @
       let nsText = text as NSString
       var i = cursor - 1
       while i >= 0 {
           let ch = nsText.substring(with: NSRange(location: i, length: 1))
           if ch == "@" {
               // Check char before @ is whitespace or start
               if i == 0 || nsText.substring(with: NSRange(location: i-1, length: 1)).rangeOfCharacter(from: .whitespaces) != nil {
                   parent.mentionQuery = nsText.substring(with: NSRange(location: i+1, length: cursor-i-1))
                   parent.mentionAnchorRange = NSRange(location: i, length: cursor - i)
                   return
               }
           }
           if ch == " " || ch == "\n" { break }
           i -= 1
       }
       parent.mentionQuery = nil
   }
   ```

2. **Add new bindings to MentionTextView**:
   ```swift
   @Binding var mentionQuery: String?       // nil = popup hidden
   @Binding var mentionAnchorRange: NSRange? // range of "@query" to replace on selection
   ```

3. **MentionPopupView** (SwiftUI):
   - Shows when `mentionQuery != nil`
   - Positioned above keyboard (use keyboard height from `ChatScreenView`)
   - Search source: `EntityIndex.shared.search(query:types:limit:)`
   - Filter tabs: `PillTabBar` with categories (All / Files / Tasks / Sessions / Agents) — `PillTabBar` already exists in `Components/PillTabBar.swift`
   - Each row: icon (SF Symbol, tinted by EntityType) + name + subtitle (path/status)
   - Max 6 visible results, scrollable
   - On select → call `mentionController.insertMention(...)` and replace `@query` range

4. **Dismissal**:
   - Space without selection → dismiss (set `mentionQuery = nil`)
   - Backspace past `@` → dismiss
   - Tap outside → dismiss
   - Escape key → dismiss

5. **Wire into ChatInputOverlay** (`ChatButtonsView.swift`):
   ```swift
   @State private var mentionQuery: String? = nil
   @State private var mentionAnchorRange: NSRange? = nil

   // In body, overlay:
   .overlay(alignment: .top) {
       if mentionQuery != nil {
           MentionPopupView(
               query: mentionQuery ?? "",
               onSelect: { entity in
                   // Remove @query text, insert mention chip
                   mentionController.replaceMention(
                       range: mentionAnchorRange!,
                       entity: entity
                   )
                   mentionQuery = nil
               },
               onDismiss: { mentionQuery = nil }
           )
           .offset(y: -popupHeight) // position above input
       }
   }
   ```

6. **Add `replaceMention(range:entity:)` to MentionTextController**:
   - Delete text in `mentionAnchorRange` (the `@query` text)
   - Insert `MentionAttachment` (from Task 2) at that position

**Data source note**: `EntityIndex.shared.search(query:types:limit:)` already exists and supports FTS5 prefix matching. When query is empty it returns recent entities. The types filter maps to `EntityType` enum. No new data layer work needed.

---

### Task 4: Editing and Cursor Behavior

**Goal**: Mention chips behave as atomic units — can't edit inside them, backspace highlights then deletes.

**Files to modify**:
- `Components/MentionTextView.swift` — Coordinator delegate methods.

**Implementation**:

1. **Atomic cursor movement** — `textView(_:shouldChangeTextIn:replacementText:)`:
   - When cursor is adjacent to a `MentionAttachment`, skip over it
   - When backspace hits a mention: first press highlights (add background color), second press deletes
   - Track "pending delete" state in coordinator

   ```swift
   private var pendingDeleteRange: NSRange?

   func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
       // Backspace (text is empty, range.length > 0)
       if text.isEmpty && range.length == 1 {
           let attr = tv.attributedText
           if range.location < attr.length,
              attr.attribute(.attachment, at: range.location, effectiveRange: nil) is MentionAttachment {
               if pendingDeleteRange == range {
                   // Second backspace — allow deletion
                   pendingDeleteRange = nil
                   return true
               }
               // First backspace — highlight, block deletion
               pendingDeleteRange = range
               highlightMention(at: range, in: tv)
               return false
           }
       }
       pendingDeleteRange = nil
       return true
   }
   ```

2. **Highlight on pending delete** — add a yellow/red background to the mention's range temporarily. Clear on next text change.

3. **Copy/paste fallback** — when copying attributed text with mentions:
   - Override `UITextView` subclass or use `UIPasteboard` handling
   - Write plain text fallback: replace `MentionAttachment` chars with `@displayName`
   - When pasting: just paste as plain text (no mention reconstruction from clipboard)

---

### Task 5: Serialization for Sending

**Goal**: Before `gateway.sendMessage()`, convert the attributed text into plain text + structured mention metadata.

**Files to modify**:
- `Components/MentionTextView.swift` — add extraction method to `MentionTextController`.
- `Views/Chat/ChatButtonsView.swift` — change send action.
- `Services/GatewayService.swift` — extend `sendMessage` to accept mentions.

**Implementation**:

1. **Add to MentionTextController**:
   ```swift
   struct MentionRef {
       let type: EntityType
       let entityId: String
       let displayName: String
       let range: NSRange  // range in the serialized plain text
   }

   func extractMessage() -> (text: String, mentions: [MentionRef]) {
       guard let tv = textView else { return ("", []) }
       var plainText = ""
       var mentions: [MentionRef] = []
       let attr = tv.attributedText!

       attr.enumerateAttributes(in: NSRange(location: 0, length: attr.length)) { attrs, range, _ in
           if let mention = attrs[.attachment] as? MentionAttachment {
               let marker = "@[\(mention.mentionType.rawValue):\(mention.entityId):\(mention.displayName)]"
               let markerRange = NSRange(location: plainText.count, length: marker.count)
               mentions.append(MentionRef(
                   type: mention.mentionType,
                   entityId: mention.entityId,
                   displayName: mention.displayName,
                   range: markerRange
               ))
               plainText += marker
           } else {
               plainText += (attr.string as NSString).substring(with: range)
           }
       }
       return (plainText.trimmingCharacters(in: .whitespacesAndNewlines), mentions)
   }
   ```

2. **Change send action in ChatInputOverlay**:
   ```swift
   // Before:
   gateway.sendMessage(messageText.trimmingCharacters(in: .whitespacesAndNewlines))

   // After:
   let (text, mentions) = mentionController.extractMessage()
   gateway.sendMessage(text, mentions: mentions)
   ```

3. **Extend GatewayService.sendMessage**:
   - Add `mentions` parameter (default `[]`)
   - Include in `chat.send` params as structured array:
   ```swift
   "params": [
       "sessionKey": sessionKey,
       "message": messageText,
       "idempotencyKey": prepared.idempotencyKey,
       "mentions": mentions.map { [
           "type": $0.type.rawValue,
           "entityId": $0.entityId,
           "name": $0.displayName
       ] }
   ]
   ```

---

### Task 6: Render Mentions in Received Messages

**Goal**: When incoming messages contain mention markers, render them as tappable chips in the message bubble.

**Files to create/modify**:
- `Views/Chat/ChatContentView.swift` — modify message rendering.
- `Services/ContentParser.swift` or `Services/MessageParser.swift` — parse mention markers.

**Implementation**:

1. **Parse mention markers** from incoming message text:
   - Regex: `@\[(\w+):([^:]+):([^\]]+)\]`
   - Extract: type, entityId, displayName
   - Build `NSAttributedString` with `MentionAttachment` for each match

2. **Render in message bubble**:
   - Use a `UITextView` (read-only, `isEditable = false`) or `Text` with `AttributedString` (iOS 15+)
   - Mention chips are tappable → use `NSAttributedString` link attribute or `UITextView` URL interaction
   - On tap: navigate to entity (file viewer, task detail, session switch)

3. **Navigation**:
   - `EntityType.file` → file preview
   - `EntityType.task` → task detail
   - `EntityType.session` → switch to that session
   - `EntityType.agent` → agent detail (if exists)

**Note**: This task depends on how messages are currently rendered in `ChatContentView.swift`. Read that file first — messages may use `Text` with markdown, or a custom rendering pipeline. Adapt accordingly.

---

## Key Files Reference

| File | Purpose |
|---|---|
| `Components/MentionTextView.swift` | UIViewRepresentable + controller (DONE) |
| `Views/Chat/ChatButtonsView.swift` | Contains ChatInputOverlay (the visible input) |
| `Views/Chat/ChatScreenView.swift` | Layout, keyboard handling, overlay positioning |
| `Models/EntityItem.swift` | `EntityType` enum (icons, colors), `EntityItem` struct |
| `Services/EntityIndex.swift` | FTS5 search: `EntityIndex.shared.search(query:types:limit:)` |
| `Services/EntityProviders.swift` | Data providers for each entity type |
| `Services/GatewayService.swift` | `sendMessage()` at line ~1073, WebSocket frame format |
| `Components/PillTabBar.swift` | Reusable pill tab bar (for category filter in popup) |

## Build

```bash
xcodebuild -project CliOS/CliOS.xcodeproj -scheme CliOS \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## Conventions

- All `ObservableObject` classes need `@MainActor` and `import Combine`
- Use `Theme.*` for colors/fonts/spacing — never hardcode
- Singletons accessed via `.shared` (`EntityIndex.shared`, `GatewayService.shared`)
- `EntityType` defines canonical icons/colors — use those, don't invent new ones
- Dark mode only (`preferredColorScheme(.dark)`)
- Keep chip height ≤ font line height to avoid breaking text layout
