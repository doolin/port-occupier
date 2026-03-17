# Copilot Chat Session Recovery Methodology (VS Code, macOS)

This procedure recovers a lost GitHub Copilot Chat session (including GPT-5.3-Codex sessions) from local VS Code storage.

## Scope

- Platform: macOS
- Editor: VS Code
- Chat provider: GitHub Copilot Chat
- Recovery source: local VS Code user storage

## Where chat data lives

Primary VS Code user storage root:

- `~/Library/Application Support/Code/User`

Useful subfolders:

- `globalStorage`
- `workspaceStorage`

Copilot chat session data is typically found under:

- `~/Library/Application Support/Code/User/workspaceStorage/<workspace-hash>/chatSessions/*.jsonl`
- `~/Library/Application Support/Code/User/workspaceStorage/<workspace-hash>/GitHub.copilot-chat/`

## Step-by-step recovery

### 1) Confirm VS Code storage paths exist

```bash
BASE="$HOME/Library/Application Support/Code/User"
ls -la "$BASE"
ls -la "$BASE/globalStorage"
ls -la "$BASE/workspaceStorage"
```

### 2) Find Copilot chat storage folders

```bash
find "$HOME/Library/Application Support/Code/User/workspaceStorage" -maxdepth 4 -type d \
  \( -name 'GitHub.copilot-chat' -o -name '*copilot*chat*' -o -name 'chatSessions' \)
```

### 3) Identify candidate session files

For the target workspace hash, list available JSONL session files:

```bash
ls -la "$HOME/Library/Application Support/Code/User/workspaceStorage/<workspace-hash>/chatSessions"
find "$HOME/Library/Application Support/Code/User/workspaceStorage/<workspace-hash>/chatSessions" -maxdepth 2 -type f
wc -l "$HOME/Library/Application Support/Code/User/workspaceStorage/<workspace-hash>/chatSessions"/*.jsonl
```

Heuristic: larger and more recently modified files are often the active session.

### 4) Confirm the model (GPT-5.3-Codex)

Search candidate JSONL files for model metadata:

```bash
rg -n "gpt-5.3-codex|GPT-5.3-Codex|copilot/gpt-5.3-codex" \
  "$HOME/Library/Application Support/Code/User/workspaceStorage/<workspace-hash>/chatSessions"/*.jsonl
```

Expected indicators include values like:

- `modelId: "copilot/gpt-5.3-codex"`
- `name: "GPT-5.3-Codex"`

### 5) Make an immediate backup copy into your repo

```bash
mkdir -p ./recovered-chat
cp "$HOME/Library/Application Support/Code/User/workspaceStorage/<workspace-hash>/chatSessions/<session-id>.jsonl" \
  ./recovered-chat/gpt53-codex-session.jsonl
```

Optional: copy additional candidate sessions.

### 6) Validate backup integrity

```bash
ls -la ./recovered-chat
rg -n "GPT-5.3-Codex|copilot/gpt-5.3-codex" ./recovered-chat/gpt53-codex-session.jsonl
```

If matches appear, the target session data is preserved.

## Important format note

The `.jsonl` file is an event-log/state format, not a simple line-by-line conversation transcript. Some entries are diffs/patches to nested state, and some contain escaped rich-render payloads. This is normal.

## Practical extraction strategy

1. Preserve raw JSONL first (most important).
2. Build human-readable transcript second.
3. If direct extraction misses assistant text, inspect event objects to locate text-bearing payload fields.

Useful schema inspection commands:

```bash
jq -r 'keys_unsorted | @json' ./recovered-chat/gpt53-codex-session.jsonl | sed -n '1,40p'
jq -r 'select(.kind==2) | (.k|@json)' ./recovered-chat/gpt53-codex-session.jsonl
jq -c 'select((.v|type?)=="array") | .v[]? | select(has("requestId")) | {requestId, message:(.message.text//""), responseKinds:((.response//[])|map(keys_unsorted))}' ./recovered-chat/gpt53-codex-session.jsonl
```

## Safety and reliability tips

- Copy files first before attempting heavy parsing.
- Avoid destructive operations in VS Code user storage.
- Keep recovered copies under version control if the conversation is important.
- If terminal sessions are unstable, rerun commands as single compact commands.

## What was recovered in this project

Recovered artifacts in this workspace:

- `recovered-chat/gpt53-codex-session.jsonl` (raw full session backup)
- `recovered-chat/other-session.jsonl` (secondary session)
- `recovered-chat/gpt53-codex-transcript.md` (initial readable extraction)

## Quick reusable checklist

- Locate `workspaceStorage`.
- Find `chatSessions/*.jsonl`.
- Pick likely file by size and timestamp.
- Verify `gpt-5.3-codex` strings.
- Copy to safe workspace folder.
- Validate copied file with `rg`.
- Optionally parse into readable markdown.
