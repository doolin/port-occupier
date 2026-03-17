#!/usr/bin/env bash
set -euo pipefail

# Recover GitHub Copilot Chat sessions from local VS Code storage (macOS-focused).
# Default behavior targets GPT-5.3-Codex sessions and copies the best candidate.

usage() {
  cat <<'EOF'
Usage:
  recover-copilot-chat.sh [options]

Options:
  -o, --out-dir DIR           Output directory (default: ./recovered-chat)
  -b, --base-dir DIR          VS Code User base dir
                              (default: ~/Library/Application Support/Code/User)
  -w, --workspace-hash HASH   Restrict search to one workspaceStorage hash
  -m, --model-pattern REGEX   Model regex to match in session files
                              (default: gpt-5.3-codex|GPT-5.3-Codex|copilot/gpt-5.3-codex)
  -n, --dry-run               Show what would be copied, do not copy
  -h, --help                  Show this help

Examples:
  recover-copilot-chat.sh
  recover-copilot-chat.sh -w be4d0119ec4cb4464320cee537e819de
  recover-copilot-chat.sh -o ./recovered-chat -n
EOF
}

OUT_DIR="./recovered-chat"
BASE_DIR="$HOME/Library/Application Support/Code/User"
WORKSPACE_HASH=""
MODEL_PATTERN='gpt-5.3-codex|GPT-5.3-Codex|copilot/gpt-5.3-codex'
DRY_RUN=0

while (($#)); do
  case "$1" in
    -o|--out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    -b|--base-dir)
      BASE_DIR="$2"
      shift 2
      ;;
    -w|--workspace-hash)
      WORKSPACE_HASH="$2"
      shift 2
      ;;
    -m|--model-pattern)
      MODEL_PATTERN="$2"
      shift 2
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

WORKSPACE_ROOT="$BASE_DIR/workspaceStorage"
if [[ ! -d "$WORKSPACE_ROOT" ]]; then
  echo "workspaceStorage not found: $WORKSPACE_ROOT" >&2
  exit 1
fi

if [[ -n "$WORKSPACE_HASH" ]]; then
  mapfile -d '' -t ALL_FILES < <(
    find "$WORKSPACE_ROOT" \
      -type f \
      -path '*/chatSessions/*.jsonl' \
      -path "*/workspaceStorage/$WORKSPACE_HASH/chatSessions/*.jsonl" \
      -print0 2>/dev/null
  )
else
  mapfile -d '' -t ALL_FILES < <(
    find "$WORKSPACE_ROOT" -type f -path '*/chatSessions/*.jsonl' -print0 2>/dev/null
  )
fi
if [[ ${#ALL_FILES[@]} -eq 0 ]]; then
  echo "No chat session files found." >&2
  exit 1
fi

MATCHED_FILES=()
for f in "${ALL_FILES[@]}"; do
  if rg -q -i "$MODEL_PATTERN" "$f"; then
    MATCHED_FILES+=("$f")
  fi
done

if [[ ${#MATCHED_FILES[@]} -eq 0 ]]; then
  echo "No files matched model pattern: $MODEL_PATTERN" >&2
  echo "Falling back to all discovered session files." >&2
  MATCHED_FILES=("${ALL_FILES[@]}")
fi

# Rank by mtime descending and select best candidate.
RANKED=$(
  for f in "${MATCHED_FILES[@]}"; do
    stat -f $'%m\t%z\t%N' "$f"
  done | sort -nr
)

BEST_FILE=$(printf '%s\n' "$RANKED" | head -n1 | cut -f3-)
BEST_BASENAME=$(basename "$BEST_FILE")
BEST_DIRNAME=$(basename "$(dirname "$(dirname "$BEST_FILE")")")

printf 'Discovered files: %d\n' "${#ALL_FILES[@]}"
printf 'Model-matched files: %d\n' "${#MATCHED_FILES[@]}"
printf 'Best candidate: %s\n' "$BEST_FILE"
printf 'Workspace hash: %s\n' "$BEST_DIRNAME"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run enabled. No files copied."
  exit 0
fi

mkdir -p "$OUT_DIR"
cp "$BEST_FILE" "$OUT_DIR/gpt53-codex-session.jsonl"

# Also copy up to 3 newest model-matched files as extra candidates.
mkdir -p "$OUT_DIR/candidates"
printf '%s\n' "$RANKED" | head -n3 | cut -f3- | while IFS= read -r f; do
  cp "$f" "$OUT_DIR/candidates/$(basename "$f")"
done

REPORT_FILE="$OUT_DIR/recovery-report.md"
{
  echo "# Recovery Report"
  echo
  echo "- Timestamp: $(date)"
  echo "- Base dir: $BASE_DIR"
  echo "- Workspace hash: $BEST_DIRNAME"
  echo "- Model pattern: $MODEL_PATTERN"
  echo "- Files discovered: ${#ALL_FILES[@]}"
  echo "- Model-matched files: ${#MATCHED_FILES[@]}"
  echo "- Selected source: $BEST_FILE"
  echo "- Copied to: $OUT_DIR/gpt53-codex-session.jsonl"
  echo
  echo "## Top Candidates"
  printf '%s\n' "$RANKED" | head -n3 | awk -F '\t' '{printf "- mtime=%s size=%s path=%s\n", $1, $2, substr($0, index($0,$3))}'
} > "$REPORT_FILE"

echo "Recovery complete."
echo "Primary file: $OUT_DIR/gpt53-codex-session.jsonl"
echo "Report: $REPORT_FILE"
