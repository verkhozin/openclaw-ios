# OpenClaw Commands

All commands the iOS app should expose as quick actions, buttons, or menus. Sent via WebSocket as chat messages.

## Session Control

| Command | What it does | UI element |
|---------|-------------|------------|
| `/new` | New session (clear context) | Button in chat header |
| `/new <model>` | New session with specific model | Model picker -> new session |
| `/reset` | Same as /new | Alias |
| `/stop` | Abort current agent run | Stop button during streaming |
| `/compact` | Compress context (save tokens) | Auto or manual button |

## Model Selection

| Command | What it does | UI element |
|---------|-------------|------------|
| `/model` | Show current model | Settings / chat header |
| `/model list` | List available models | Model picker sheet |
| `/model <name>` | Switch model | Tap on model picker |
| `/model status` | Detailed model + provider info | Settings > Gateway > Model |

Examples: `/model opus`, `/model openai/gpt-5.2`, `/model 3` (by number from list)

## Thinking / Reasoning

| Command | What it does | UI element |
|---------|-------------|------------|
| `/think off` | No extended thinking | Toggle in settings |
| `/think low` | Low thinking | Segmented control |
| `/think medium` | Medium thinking | Segmented control |
| `/think high` | Deep thinking | Segmented control |
| `/reasoning on\|off` | Show reasoning in response | Toggle |

## Performance

| Command | What it does | UI element |
|---------|-------------|------------|
| `/fast on` | Faster responses, less quality | Toggle |
| `/fast off` | Normal quality | Toggle |
| `/verbose on\|off` | Show detailed tool output | Debug toggle |
| `/elevated on\|off\|ask` | Elevated permissions for tools | Settings |

## Usage & Status

| Command | What it does | UI element |
|---------|-------------|------------|
| `/status` | Full status (model, usage, context) | Dashboard card / pull to refresh |
| `/usage tokens` | Show tokens per response | Setting |
| `/usage cost` | Local cost summary | Monitoring tab |
| `/context` | Show context window usage | Info button in chat |
| `/whoami` | Show sender ID | Settings > Account |

## Sub-agents

| Command | What it does | UI element |
|---------|-------------|------------|
| `/subagents list` | List active sub-agents | Tasks tab |
| `/kill <id\|#\|all>` | Kill sub-agent | Swipe to delete on task |
| `/steer <id> <msg>` | Redirect sub-agent | Long press > Steer |
| `/tell <id> <msg>` | Alias for steer | Same |

## Exec Approvals

| Command | What it does | UI element |
|---------|-------------|------------|
| `/approve <id> allow-once` | Allow one command | Approve button |
| `/approve <id> allow-always` | Always allow this command | Button with confirmation |
| `/approve <id> deny` | Deny command | Deny button |
| `/exec` | Show current exec policy | Settings > Security |

## Cron

| Command | What it does | UI element |
|---------|-------------|------------|
| Cron managed via Gateway API, not slash commands | | Cron manager screen |

## Session Tuning

| Command | What it does | UI element |
|---------|-------------|------------|
| `/queue` | Show queue settings | Advanced settings |
| `/send on\|off` | Enable/disable agent sending | Safety toggle |
| `/activation mention\|always` | When agent responds in groups | Group settings |

## TTS / Voice

| Command | What it does | UI element |
|---------|-------------|------------|
| `/tts off` | No text-to-speech | Voice toggle |
| `/tts always` | Read all responses | Voice toggle |
| `/tts tagged` | Read only tagged responses | Voice toggle |

## System

| Command | What it does | UI element |
|---------|-------------|------------|
| `/help` | Show help | Help screen |
| `/commands` | List all commands | Command reference |
| `/restart` | Restart agent session | Settings > Advanced |

## iOS App Command Groups

How to organize these in the app:

### Chat Header Bar
- Model name (tap to switch)
- New Session button
- Stop button (visible during streaming only)

### Settings Sheet (swipe from chat)
- Model picker
- Thinking level (segmented: off / low / medium / high)
- Fast mode toggle
- Reasoning toggle
- Elevated toggle
- Usage display mode

### Tasks Tab
- Sub-agent list with kill/steer actions
- Approval cards with allow/deny buttons

### Dashboard
- Status card (auto-refreshes)
- Usage rings
- Context usage bar

### Long Press Menu (on any agent message)
- Copy
- Regenerate
- Compact context
