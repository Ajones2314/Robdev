#!/usr/bin/env bash
# jarvis-review: has OpenJarvis (your local AI) review code, one file at a time.
#
# Usage (run inside a git project folder):
#   jarvis-review                 review files changed compared to main
#   jarvis-review --base dev      compare against another branch instead
#   jarvis-review path/a.luau ... review exactly these files
#   jarvis-review --cloud gemini-3.8-flash ...
#                                 use a stronger cloud model instead of the local
#                                 one (needs that provider's API key, e.g.
#                                 GEMINI_API_KEY or OPENAI_API_KEY)
#
# It reads the project's checklist from .jarvis/review-checklist.md (if there is
# one) and saves the full report to .jarvis/last-review.md.
set -euo pipefail

BASE="main"
FILES=()
ENGINE_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --base) BASE="$2"; shift 2 ;;
        --cloud) ENGINE_ARGS=(--engine cloud --model "$2"); shift 2 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) FILES+=("$1"); shift ;;
    esac
done

if ! command -v jarvis >/dev/null 2>&1; then
    echo "jarvis-review: the 'jarvis' command was not found. Install OpenJarvis first." >&2
    exit 1
fi
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "jarvis-review: run this inside a git project folder." >&2
    exit 1
}
cd "$ROOT"

if [ ${#FILES[@]} -eq 0 ]; then
    if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
        git fetch --quiet origin "$BASE" 2>/dev/null || true
        BASE="origin/$BASE"
    fi
    while IFS= read -r f; do
        [ -n "$f" ] && FILES+=("$f")
    done < <(git diff --name-only --diff-filter=AM "$BASE"...HEAD -- \
        '*.luau' '*.lua' '*.py' '*.js' '*.jsx' '*.ts' '*.tsx' '*.go' '*.rs' '*.swift')
fi

if [ ${#FILES[@]} -eq 0 ]; then
    echo "Nothing to review: no code files changed compared to $BASE."
    exit 0
fi

CHECKLIST_FILE=".jarvis/review-checklist.md"
if [ -f "$CHECKLIST_FILE" ]; then
    CHECKLIST=$(cat "$CHECKLIST_FILE")
else
    CHECKLIST="Review this file for real bugs, security problems and data-loss risks.
Only report problems you can point to with a quoted line. For each one give:
Problem, Line, How it happens, Fix, Confidence (HIGH or LOW).
If you find nothing real, say so. Do not invent problems."
fi

mkdir -p .jarvis
REPORT=".jarvis/last-review.md"
{
    echo "# OpenJarvis review"
    echo
    echo "Branch: $(git rev-parse --abbrev-ref HEAD) (compared to $BASE), $(date '+%Y-%m-%d %H:%M')"
    echo
} > "$REPORT"

TOTAL=${#FILES[@]}
N=0
for f in "${FILES[@]}"; do
    N=$((N + 1))
    if [ ! -f "$f" ]; then
        echo "Skipping $f (file not found)"
        continue
    fi
    echo
    echo "=== [$N/$TOTAL] Reviewing $f ==="
    PROMPT="$CHECKLIST

## The file to review: $f

\`\`\`
$(cat "$f")
\`\`\`"
    # The simple agent answers directly with no tool steps, so it can't run
    # out of turns. --no-context keeps old chats out of the review, and
    # --quiet hides the banner.
    ANSWER=$(jarvis --quiet ask --agent simple --no-context --no-stream \
        --max-tokens 2048 ${ENGINE_ARGS[@]+"${ENGINE_ARGS[@]}"} "$PROMPT") || ANSWER="(OpenJarvis failed on this file; error shown above)"
    [ -z "$ANSWER" ] && ANSWER="(no answer)"
    printf '%s\n' "$ANSWER"
    {
        echo "## $f"
        echo
        printf '%s\n' "$ANSWER"
        echo
    } >> "$REPORT"
done

echo
echo "Done. Full report saved to $ROOT/$REPORT"
