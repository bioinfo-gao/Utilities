#!/usr/bin/env bash
set -euo pipefail

ASSETS=/home/gao/Utilities/AI_and_Agent/Agent_Assets
AGENT_REGISTRY="$ASSETS/registry/agents.json"
fail=0

expect_link() {
  local source=$1 target=$2
  if [[ ! -L "$target" || "$(readlink -f "$target")" != "$(readlink -f "$source")" ]]; then
    printf 'FAIL link: %s should resolve to %s\n' "$target" "$source" >&2
    fail=1
  fi
}

python3 -m json.tool "$ASSETS/registry/skills.json" >/dev/null
python3 -m json.tool "$AGENT_REGISTRY" >/dev/null
python3 -m json.tool "$ASSETS/adapters/codex/hooks.json" >/dev/null
python3 - "$ASSETS" "$AGENT_REGISTRY" <<'PY'
import ast
import json
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
registry_path = pathlib.Path(sys.argv[2])
registry = json.loads(registry_path.read_text(encoding="utf-8"))
canonical = root / "instructions" / "SHARED_AGENT_RULES.md"
assert registry["schema_version"] == 1
assert pathlib.Path(registry["canonical_rule"]) == canonical
assert registry["agents"]
ids, entries = set(), set()
for agent in registry["agents"]:
    assert set(agent) == {"id", "display_name", "rule_entry", "rule_entry_mode"}
    assert agent["id"] not in ids and agent["rule_entry"] not in entries
    assert agent["rule_entry_mode"] == "symlink"
    assert pathlib.Path(agent["rule_entry"]).is_absolute()
    ids.add(agent["id"]); entries.add(agent["rule_entry"])
for path in [root / "adapters/codex/pre_tool_policy.py", *sorted((root / "hooks/core").glob("*.py")), *sorted((root / "hooks/core/checks").glob("*.py"))]:
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
test -s "$ASSETS/instructions/SHARED_AGENT_RULES.md"

while IFS=$'\t' read -r agent_id rule_entry; do
  expect_link "$ASSETS/instructions/SHARED_AGENT_RULES.md" "$rule_entry"
done < <(python3 - "$AGENT_REGISTRY" <<'PY'
import json
import sys
for agent in json.load(open(sys.argv[1], encoding="utf-8"))["agents"]:
    print(f'{agent["id"]}\t{agent["rule_entry"]}')
PY
)
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
