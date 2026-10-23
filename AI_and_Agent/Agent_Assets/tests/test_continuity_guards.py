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

    state.write_text(json.dumps({"schema_version": 1, "projects": [{
        "id": "fixture", "status": "active", "expected_tmux_session": "definitely-not-running",
        "next_stage": "fixture next stage",
    }]}))
    assert run(ADAPTERS["claude"], state)["decision"] == "block"
    assert run(ADAPTERS["codex"], state)["decision"] == "block"
    assert run(ADAPTERS["antigravity"], state)["decision"] == "continue"

print("continuity guard adapter tests passed")
