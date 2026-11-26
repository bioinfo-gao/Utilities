#!/usr/bin/env python3
"""Protocol-level tests for the one shared continuity evaluator and three adapters."""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path("/home/gao/Utilities/AI_and_Agent/Agent_Assets")
ADAPTERS = {
    "claude": ROOT / "hooks/core/continuity_stop_guard.py",
    "codex": ROOT / "adapters/codex/continuity_stop_guard.py",
    "antigravity": ROOT / "adapters/antigravity/continuity_stop_guard.py",
}


def run(adapter: Path, state: Path) -> dict:
    env = dict(os.environ, ACTIVE_PROJECT_STATE_FILE=str(state))
    result = subprocess.run(
        ["python3", str(adapter)],
        input="{}",
        text=True,
        capture_output=True,
        env=env,
        check=True,
    )
    return json.loads(result.stdout) if result.stdout.strip() else {}


with tempfile.TemporaryDirectory() as tmp:
    state = Path(tmp) / "active_projects.json"
    state.write_text(json.dumps({"schema_version": 1, "projects": [{"id": "done", "status": "complete"}]}))
    assert run(ADAPTERS["claude"], state) == {}
    assert run(ADAPTERS["codex"], state) == {"continue": True}
    assert run(ADAPTERS["antigravity"], state) == {}

    # 真实 SSOT 词汇是 "running"（2026-11-26 回归：原夹具只用 "active"，生产从未出现该值，测试绿而生产静默）
    for status in ("running", "active"):
        state.write_text(json.dumps({"schema_version": 1, "projects": [{
            "id": "fixture", "status": status, "agent": "claude_code",
            "expected_tmux_session": "definitely-not-running", "next_stage": "fixture next stage",
        }]}))
        assert run(ADAPTERS["claude"], state)["decision"] == "block", status
        assert run(ADAPTERS["codex"], state)["decision"] == "block", status
        assert run(ADAPTERS["antigravity"], state)["decision"] == "continue", status

    # Claude 的 Stop hook 不因别的 Agent 的项目卡住本 Agent
    state.write_text(json.dumps({"schema_version": 1, "projects": [{
        "id": "other", "status": "running", "agent": "codex",
        "expected_tmux_session": "definitely-not-running", "next_stage": "x",
    }]}))
    assert run(ADAPTERS["claude"], state) == {}

    # blocked / complete 不触发
    state.write_text(json.dumps({"schema_version": 1, "projects": [{
        "id": "b", "status": "blocked", "agent": "claude_code",
        "expected_tmux_session": "definitely-not-running", "next_stage": "x",
    }]}))
    assert run(ADAPTERS["claude"], state) == {}

print("continuity guard adapter tests passed")
