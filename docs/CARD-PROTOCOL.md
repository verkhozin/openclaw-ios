# Card Protocol

## Format

Cards are standard markdown codeblocks with `card:type` as language:

````
```card:github.pr
repo: verkh-tech/site
title: Fix hero animation
status: merged
ci: passed
diff: +42 -8
url: https://github.com/verkh-tech/site/pull/15
```
````

Inside: YAML-like `key: value`, one per line. Simple, human-readable, machine-parseable.

### Actions

Separator `---`, then metadata for UI buttons:

````
```card:email.draft
to: alex@rivadata.com
subject: Partnership proposal
preview: Hi Alex, I noticed Riva Data recently...
---
actions: approve, edit, discard
```
````

## Capability Negotiation

App declares support at WebSocket connect:

```json
{
  "caps": ["cards.v1"],
  "cardTypes": ["github.pr", "github.issue", "email.inbox", ...]
}
```

Gateway injects into agent system prompt (only for this session):

> "This session supports rich cards. When outputting structured data, use ```card:type``` codeblocks with key: value pairs. Supported types: [list from caps]."

No caps = no cards = plain text. Telegram, Discord, CLI unaffected.

## Fallback

In clients without card support, the codeblock renders as readable text:

```
repo: verkh-tech/site
title: Fix hero animation
status: merged
```

## Supported Types

See SERVICE-CARDS.md for full list.

## Skill

A `card-format` skill exists as reference for the agent. Agent reads it when needed, not on every message.
