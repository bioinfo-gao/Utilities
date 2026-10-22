#!/usr/bin/env python3
"""Codex adapter for portable Claude safety guards.

Codex does not support PreToolUse `ask`; hard denials remain denials, while
confirmation-needed actions are returned as model-visible context and continue
through Codex's normal approval system. This adapter intentionally never claims
that such actions received Claude-equivalent hard enforcement.
"""
import json
import subprocess
import sys

CORE = "/home/gao/Utilities/AI_and_Agent/Agent_Assets/hooks/core"
GUARDS = ["guard_destructive_bash.py", "guard_search_symlink.py", "guard_inline_email.py"]


def run_guard(name, payload):
    result = subprocess.run(
        [sys.executable, f"{CORE}/{name}"], input=payload, text=True,
        capture_output=True, timeout=40,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def main():
    payload = sys.stdin.read()
    for name in GUARDS:
        result = run_guard(name, payload)
        if not result:
            continue
        output = result.get("hookSpecificOutput", {})
        decision = output.get("permissionDecision")
        reason = output.get("permissionDecisionReason", "")
        if decision == "deny":
            print(json.dumps(result, ensure_ascii=False))
            return
        if decision == "ask":
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": (
                    "Shared safety policy requires explicit user confirmation before this action. "
                    "Use Codex's normal approval flow; do not claim that the shared hook has approved it.\n"
                    + reason
                ),
            }}, ensure_ascii=False))
            return


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Preserve the source hooks' fail-open behavior while leaving normal Codex approval in control.
        pass
