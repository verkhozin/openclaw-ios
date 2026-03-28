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
| `/think off` | No extended thinking | Segmented control |
| `/think minimal` | Minimal thinking | Segmented control |
| `/think low` | Low thinking | Segmented control |
| `/think medium` | Medium thinking | Segmented control |
| `/think high` | Deep thinking | Segmented control |
| `/think xhigh` | Maximum thinking | Segmented control |
| `/reasoning on` | Show reasoning in separate message | Toggle |
| `/reasoning off` | Hide reasoning | Toggle |
| `/reasoning stream` | Stream reasoning (Telegram draft) | Toggle |

## Performance

| Command | What it does | UI element |
|---------|-------------|------------|
| `/fast on` | Faster responses, less quality | Toggle |
| `/fast off` | Normal quality | Toggle |
| `/verbose on\|off` | Show detailed tool output | Debug toggle |
| `/elevated on\|off\|ask\|full` | Elevated permissions (full = skip approvals) | Settings |

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
| `/subagents kill <id>` | Kill sub-agent | Swipe to delete on task |
| `/subagents log <id>` | View sub-agent logs | Tap > Logs |
| `/subagents info <id>` | Detailed sub-agent info | Tap > Details |
| `/subagents send <id> <msg>` | Send message to sub-agent | Action sheet |
| `/subagents steer <id> <msg>` | Redirect sub-agent in-flight | Long press > Steer |
| `/subagents spawn` | Spawn new sub-agent | Create button |
| `/kill <id\|#\|all>` | Quick kill (shortcut) | Swipe to delete |
| `/steer <id> <msg>` | Quick steer (shortcut) | Long press > Steer |
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
| `/tts off` | No text-to-speech | Voice settings |
| `/tts always` | Read all responses aloud | Voice settings |
| `/tts inbound` | Read inbound messages only | Voice settings |
| `/tts tagged` | Read only tagged responses | Voice settings |
| `/tts status` | Show current TTS config | Voice settings |
| `/tts provider` | Show/set TTS provider | Provider picker |
| `/tts limit <seconds>` | Max TTS audio length | Number input |
| `/tts summary` | Read summary only | Voice settings |
| `/tts audio` | Audio playback control | Playback controls |

## Focus / Thread Binding

| Command | What it does | UI element |
|---------|-------------|------------|
| `/focus <target>` | Bind thread to session/subagent | Focus picker |
| `/unfocus` | Remove thread binding | Unfocus button |

## ACP (Agent Code Platform)

| Command | What it does | UI element |
|---------|-------------|------------|
| `/acp spawn` | Spawn ACP coding session | ACP section in Tasks |
| `/acp cancel` | Cancel ACP session | Swipe to cancel |
| `/acp steer <msg>` | Redirect ACP session | Long press > Steer |
| `/acp close` | Close ACP session | Close button |
| `/acp status` | Show ACP session status | Status badge |
| `/acp set-mode run\|session` | Set ACP mode | Mode picker |
| `/acp set <key> <value>` | Set ACP option | Settings |
| `/acp cwd <path>` | Set working directory | Path picker |
| `/acp permissions` | Show/set permissions | Permissions sheet |
| `/acp timeout <seconds>` | Set timeout | Number input |
| `/acp model <name>` | Set ACP model | Model picker |
| `/acp reset-options` | Reset to defaults | Reset button |
| `/acp doctor` | Diagnose ACP issues | Debug section |
| `/acp install` | Install ACP runtime | Setup wizard |
| `/acp sessions` | List ACP sessions | ACP tab |

## Bash / Shell

| Command | What it does | UI element |
|---------|-------------|------------|
| `/bash <cmd>` | Run shell command on host | Terminal input |
| `! <cmd>` | Alias for /bash | Same |
| `!poll` | Check running command output | Poll button |
| `!stop` | Stop running command | Stop button |

## Session Management

| Command | What it does | UI element |
|---------|-------------|------------|
| `/session idle <duration\|off>` | Auto-unfocus after inactivity | Settings > Sessions |
| `/session max-age <duration\|off>` | Hard max-age auto-unfocus | Settings > Sessions |
| `/export-session [path]` | Export session to HTML | Share button |
| `/agents` | List thread-bound agents | Agents list |

## Discord Voice (Discord only)

| Command | What it does | UI element |
|---------|-------------|------------|
| `/vc join` | Join voice channel | N/A (Discord) |
| `/vc leave` | Leave voice channel | N/A (Discord) |
| `/vc status` | Voice channel status | N/A (Discord) |

## Skills

| Command | What it does | UI element |
|---------|-------------|------------|
| `/skill <name> [input]` | Run a skill by name | Skills browser |

## Routing / Docking

| Command | What it does | UI element |
|---------|-------------|------------|
| `/dock-telegram` | Switch replies to Telegram | Channel picker |
| `/dock-discord` | Switch replies to Discord | Channel picker |
| `/dock-slack` | Switch replies to Slack | Channel picker |

## Security

| Command | What it does | UI element |
|---------|-------------|------------|
| `/allowlist` | List allowlisted users | Settings > Security |
| `/allowlist add <id>` | Add to allowlist | Add button |
| `/allowlist remove <id>` | Remove from allowlist | Swipe to remove |

## Config (owner-only)

| Command | What it does | UI element |
|---------|-------------|------------|
| `/config show` | Show full config | Config viewer |
| `/config get <key>` | Get config value | Search |
| `/config set <key>=<value>` | Set config value | Edit field |
| `/config unset <key>` | Remove config value | Delete |
| `/debug show` | Show runtime overrides | Debug panel |
| `/debug set <key>=<value>` | Set runtime override | Debug edit |
| `/debug reset` | Clear all overrides | Reset button |

## System

| Command | What it does | UI element |
|---------|-------------|------------|
| `/help` | Show help | Help screen |
| `/commands` | List all commands | Command reference |
| `/restart` | Restart agent session | Settings > Advanced |
| `/context list\|detail\|json` | Show context breakdown | Info button |

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
