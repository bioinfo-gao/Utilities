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


def invoke(
    state: Path,
    state_home: Path,
    mailer: Path,
    *,
    grace_seconds: int | None = None,
) -> str:
    env = dict(
        os.environ,
        ACTIVE_PROJECT_STATE_FILE=str(state),
        XDG_STATE_HOME=str(state_home),
        CONTINUITY_GUARD_MAILER=str(mailer),
    )
    if grace_seconds is not None:
        env["CONTINUITY_GUARD_GRACE_SECONDS"] = str(grace_seconds)
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
    pending = invoke(state, work / "state", mailer)
    assert "CONTINUITY_GUARD_PENDING:" in pending
    assert "grace_seconds=1800" in pending

    first = invoke(state, work / "state", mailer, grace_seconds=0)
    assert "CONTINUITY_GUARD_ALERT: alerted=True missing_seconds=" in first
    assert "tty_recipients=0 email_exit=0" in first
    second = invoke(state, work / "state", mailer, grace_seconds=0)
    assert "CONTINUITY_GUARD_ALERT: alerted=False missing_seconds=" in second
    assert "tty_recipients=0 not_attempted" in second

    # A genuine recovery clears the outage episode; a later absence must be
    # considered a new event and receive its own first severe alert.
    state.write_text(json.dumps({"projects": [{"id": "done", "status": "complete"}]}))
    assert invoke(state, work / "state", mailer) == "CONTINUITY_GUARD_OK: no active project is missing its expected tmux session"
    state.write_text(json.dumps({"projects": [{
        "id": "fixture", "status": "active", "expected_tmux_session": "definitely-not-running",
        "next_stage": "fixture next stage",
    }]}))
    renewed = invoke(state, work / "state", mailer, grace_seconds=0)
    assert "CONTINUITY_GUARD_ALERT: alerted=True missing_seconds=" in renewed

print("client-independent continuity guard tests passed")
