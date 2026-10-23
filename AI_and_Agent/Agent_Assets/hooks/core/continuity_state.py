#!/usr/bin/env python3
"""Shared evaluator for the active-project continuity invariant.

This module deliberately contains no provider-specific hook protocol.  Claude,
Codex, Antigravity, and any future adapter call the same evaluator and only
translate its result to their native Stop-hook response.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any


DEFAULT_STATE = Path(
    "/home/gao/Utilities/AI_and_Agent/Agent_Assets/runtime/active_projects.json"
)
SAFE_SESSION = re.compile(r"^[A-Za-z0-9_.-]+$")


def _state_path() -> Path:
    """Allow an isolated fixture only for automated tests."""
    return Path(os.environ.get("ACTIVE_PROJECT_STATE_FILE", DEFAULT_STATE))


def _session_exists(name: str) -> bool:
    if not SAFE_SESSION.fullmatch(name):
        return False
    try:
        return subprocess.run(
            ["tmux", "has-session", "-t", name],
            capture_output=True,
            timeout=3,
            check=False,
        ).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def continuity_violation() -> str | None:
    """Return a blocking reason when an autonomous project is idle.

    A missing or invalid central state is fail-closed: silently allowing a turn
    to end would recreate the exact unattended-project failure this guard
    exists to prevent.
    """
    state_path = _state_path()
    try:
        state: dict[str, Any] = json.loads(state_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return f"Cannot read central active-project state {state_path}: {type(exc).__name__}."

    projects = state.get("projects")
    if not isinstance(projects, list):
        return f"Central active-project state {state_path} has no valid projects list."

    idle: list[str] = []
    for project in projects:
        if not isinstance(project, dict) or project.get("status") != "active":
            continue
        project_id = str(project.get("id", "unnamed"))
        session = project.get("expected_tmux_session")
        if not isinstance(session, str) or not SAFE_SESSION.fullmatch(session):
            idle.append(f"{project_id}: expected_tmux_session is missing or unsafe")
        elif not _session_exists(session):
            next_stage = str(project.get("next_stage", "unspecified"))
            idle.append(
                f"{project_id}: expected tmux '{session}' is absent; next stage: {next_stage}"
            )

    if not idle:
        return None
    return (
        "ACTIVE-PROJECT CONTINUITY VIOLATION. "
        + " | ".join(idle)
        + ". Do not end this turn: launch and verify the next stage, or update the "
        "central active-project state to documented complete/blocked."
    )
