#!/usr/bin/env bash
set -euo pipefail

ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
fail=0

expect_link() {
  local source=$1 target=$2
  if [[ ! -L "$target" || "$(readlink -f "$target")" != "$(readlink -f "$source")" ]]; then
    printf 'FAIL link: %s should resolve to %s\n' "$target" "$source" >&2
    fail=1
  fi
}

python3 -m json.tool "$ASSETS/registry/skills.json" >/dev/null
python3 -m json.tool "$ASSETS/adapters/codex/hooks.json" >/dev/null
python3 - "$ASSETS" <<'PY'
import ast
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
for path in [root / "adapters/codex/pre_tool_policy.py", *sorted((root / "hooks/core").glob("*.py")), *sorted((root / "hooks/core/checks").glob("*.py"))]:
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
test -s "$ASSETS/instructions/SHARED_AGENT_RULES.md"

expect_link "$ASSETS/instructions/SHARED_AGENT_RULES.md" /home/gao/.claude/CLAUDE.md
expect_link "$ASSETS/instructions/SHARED_AGENT_RULES.md" /home/gao/.codex/AGENTS.md
expect_link "$ASSETS/instructions/SHARED_AGENT_RULES.md" /home/gao/.gemini/AGENTS.md
expect_link "$ASSETS/adapters/codex/hooks.json" /home/gao/.codex/hooks.json
for source in "$ASSETS"/skills/*; do
  name=$(basename "$source")
  test -f "$source/SKILL.md" || { printf 'FAIL missing SKILL.md: %s\n' "$source" >&2; fail=1; continue; }
  expect_link "$source" "/home/gao/.claude/skills/$name"
  expect_link "$source" "/home/gao/.codex/skills/$name"
  expect_link "$source" "/home/gao/.gemini/config/skills/$name"
done
expect_link /home/gao/.gemini/config/skills /home/gao/.gemini/skills
for source in "$ASSETS"/hooks/core/*.py; do
  expect_link "$source" "/home/gao/.claude/hooks/$(basename "$source")"
done
expect_link "$ASSETS/hooks/core/checks" /home/gao/.claude/hooks/checks

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
printf 'Agent Assets verification passed.\n'
