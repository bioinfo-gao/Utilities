#!/usr/bin/env python3
"""Regression tests for the client-independent cron guard."""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path("/home/gao/Utilities/AI_and_Agent/Agent_Assets")
GUARD = ROOT / "scripts/continuity_guard.py"


def invoke(state: Path, state_home: Path, mailer: Path) -> str:
    env = dict(
        os.environ,
        ACTIVE_PROJECT_STATE_FILE=str(state),
        XDG_STATE_HOME=str(state_home),
        CONTINUITY_GUARD_MAILER=str(mailer),
    )
    result = subprocess.run(
        ["python3", str(GUARD), "--once", "--no-tty"],
        text=True,
        capture_output=True,
        env=env,
        check=True,
    )
    return result.stdout.strip()


with tempfile.TemporaryDirectory() as tmp:
    work = Path(tmp)
    state = work / "active_projects.json"
    mailer = work / "fake_mailer.sh"
    mailer.write_text("#!/usr/bin/env bash\ncat >/dev/null\nexit 0\n")
    mailer.chmod(0o700)
    state.write_text(json.dumps({"projects": [{"id": "done", "status": "complete"}]}))
    assert invoke(state, work / "state", mailer) == "CONTINUITY_GUARD_OK: no active project is missing its expected tmux session"

    state.write_text(json.dumps({"projects": [{
        "id": "fixture", "status": "active", "expected_tmux_session": "definitely-not-running",
        "next_stage": "fixture next stage",
    }]}))
    first = invoke(state, work / "state", mailer)
    assert "CONTINUITY_GUARD_ALERT: alerted=True tty_recipients=0 email_exit=0" in first
    second = invoke(state, work / "state", mailer)
    assert "CONTINUITY_GUARD_ALERT: alerted=False tty_recipients=0 not_attempted" in second

print("client-independent continuity guard tests passed")
