#!/usr/bin/env python3
"""Resume a registered active Codex project only after its configured delay.

This controller does not invent project state.  `active_projects.json` remains
the sole active-project SSOT; the companion configuration only records how a
specific saved Codex session may be resumed and the resulting audit trail.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


ASSETS = Path("/home/gao/Utilities/AI_and_Agent/Agent_Assets")
RUNTIME = ASSETS / "runtime"
ACTIVE = RUNTIME / "active_projects.json"
CONFIG = RUNTIME / "codex_active_project_autostart.json"
LOCK = RUNTIME / "codex_active_project_autostart.lock"
LOG_DIR = RUNTIME / "codex_active_project_autostart_logs"
USAGE_RE = re.compile(r"(?:usage|rate)[ _-]?limit|usage[^\n]{0,80}(?:reset|exceeded)", re.I)


def now() -> datetime:
    return datetime.now(timezone.utc)


def stamp(value: datetime | None = None) -> str:
    return (value or now()).isoformat(timespec="seconds")


def parse_time(value: str) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def load(path: Path) -> dict:
    with path.open() as handle:
        return json.load(handle)


def save(path: Path, value: dict) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def tmux_live(name: str) -> bool:
    if not name:
        return False
    return subprocess.run(["tmux", "has-session", "-t", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def append_event(event: dict) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with (LOG_DIR / "controller_events.jsonl").open("a") as handle:
        handle.write(json.dumps(event, ensure_ascii=False) + "\n")


def entry_for(config: dict, project_id: str) -> dict:
    for entry in config.get("entries", []):
        if entry.get("active_project_id") == project_id:
            return entry
    raise KeyError(project_id)


def active_for(project_id: str) -> dict | None:
    for project in load(ACTIVE).get("projects", []):
        if project.get("id") == project_id:
            return project
    return None


def require_running_project_coverage(config: dict) -> None:
    """Fail loudly rather than silently omitting any currently running project."""
    running = {
        project["id"]
        for project in load(ACTIVE).get("projects", [])
        if project.get("status") == "running"
    }
    armed = {
        entry.get("active_project_id")
        for entry in config.get("entries", [])
        if entry.get("status") == "armed"
    }
    missing = sorted(running - armed)
    if missing:
        append_event({"at": stamp(), "event": "coverage_failure", "missing_running_projects": missing})
        raise RuntimeError("Autostart is not armed for every running project: " + ", ".join(missing))


def heartbeat(project_id: str) -> None:
    config = load(CONFIG)
    entry = entry_for(config, project_id)
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "explicit_agent_heartbeat"
    save(CONFIG, config)
    append_event({"at": stamp(), "event": "heartbeat", "project": project_id})


def choose_trigger(entry: dict, active: dict, has_live_session: bool) -> tuple[str, datetime] | None:
    if active.get("status") != "running" or entry.get("status") != "armed":
        return None
    if entry.get("project_root") != active.get("project_root"):
        raise ValueError("configured project root does not match active-project SSOT")
    if entry.get("last_worker_result") == "non_usage_failure":
        return None
    if has_live_session:
        return None
    usage_at = parse_time(entry.get("last_usage_limit_at", ""))
    if usage_at:
        repeated = int(entry.get("consecutive_usage_limit_events", 0)) > 1
        delay_key = "repeated_usage_limit_wait_seconds" if repeated else "initial_usage_limit_wait_seconds"
        trigger = "hourly_usage_limit_retry" if repeated else "initial_usage_limit_resume"
        return trigger, usage_at + timedelta(seconds=int(entry[delay_key]))
    missing_at = parse_time(entry.get("missing_tmux_observed_at", ""))
    if missing_at:
        return "stale_active_fallback", missing_at + timedelta(seconds=int(entry["fallback_stale_seconds"]))
    return "observe_missing_tmux", now()


def launch(project_id: str, config: dict, entry: dict, trigger: str) -> None:
    token = now().strftime("%Y%m%dT%H%M%SZ")
    session = f"codex_autoresume_{project_id}_{token}"[:90]
    # tmux executes this same verified script; no shell interpolation of prompt/config occurs.
    command = ["tmux", "new-session", "-d", "-s", session, sys.executable, str(Path(__file__).resolve()), "--run-worker", project_id]
    subprocess.run(command, check=True)
    entry["last_launch_at"] = stamp()
    entry["last_worker_session"] = session
    entry["last_trigger"] = trigger
    if trigger in {"initial_usage_limit_resume", "hourly_usage_limit_retry"}:
        entry["last_usage_limit_at"] = ""
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "autostart_launch"
    entry["missing_tmux_observed_at"] = ""
    save(CONFIG, config)
    append_event({"at": stamp(), "event": "worker_launched", "project": project_id, "tmux_session": session, "trigger": trigger})


def once() -> None:
    config = load(CONFIG)
    require_running_project_coverage(config)
    for entry in config.get("entries", []):
        project_id = entry.get("active_project_id", "")
        active = active_for(project_id)
        if not active:
            append_event({"at": stamp(), "event": "configuration_error", "project": project_id, "reason": "active project not found"})
            continue
        expected_live = tmux_live(active.get("expected_tmux_session", ""))
        worker_live = tmux_live(entry.get("last_worker_session", ""))
        if expected_live or worker_live:
            if entry.get("missing_tmux_observed_at"):
                entry["missing_tmux_observed_at"] = ""
                save(CONFIG, config)
                append_event({"at": stamp(), "event": "tmux_restored", "project": project_id})
            continue
        try:
            selected = choose_trigger(entry, active, has_live_session=False)
        except ValueError as exc:
            append_event({"at": stamp(), "event": "configuration_error", "project": project_id, "reason": str(exc)})
            continue
        if not selected:
            continue
        trigger, eligible_at = selected
        if trigger == "observe_missing_tmux":
            entry["missing_tmux_observed_at"] = stamp()
            save(CONFIG, config)
            append_event({"at": stamp(), "event": "missing_tmux_observed", "project": project_id})
            continue
        if now() < eligible_at:
            continue
        launch(project_id, config, entry, trigger)


def run_worker(project_id: str) -> None:
    config = load(CONFIG)
    entry = entry_for(config, project_id)
    active = active_for(project_id)
    if not active or active.get("status") != "running":
        append_event({"at": stamp(), "event": "worker_cancelled", "project": project_id, "reason": "project not running"})
        return
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_DIR / f"{project_id}_{now().strftime('%Y%m%dT%H%M%SZ')}.jsonl"
    entry["last_worker_started_at"] = stamp()
    entry["last_worker_log"] = str(log)
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "autostart_worker_started"
    save(CONFIG, config)
    command = [entry["codex_binary"], "exec", "resume", "--json", entry["codex_session_id"], entry["continuation_prompt"]]
    with log.open("w") as handle:
        result = subprocess.run(command, cwd=entry["project_root"], stdout=handle, stderr=subprocess.STDOUT)
    text = log.read_text(errors="replace")
    config = load(CONFIG)
    entry = entry_for(config, project_id)
    entry["last_worker_finished_at"] = stamp()
    entry["last_worker_exit_code"] = result.returncode
    entry["last_worker_session"] = ""
    entry["last_worker_result"] = "usage_limit_detected" if USAGE_RE.search(text) else ("completed_or_stopped" if result.returncode == 0 else "non_usage_failure")
    if entry["last_worker_result"] == "usage_limit_detected":
        entry["last_usage_limit_at"] = stamp()
        entry["consecutive_usage_limit_events"] = int(entry.get("consecutive_usage_limit_events", 0)) + 1
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "autostart_worker_finished"
    save(CONFIG, config)
    append_event({"at": stamp(), "event": "worker_finished", "project": project_id, "exit_code": result.returncode, "result": entry["last_worker_result"], "log": str(log)})


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--once", action="store_true")
    group.add_argument("--heartbeat")
    group.add_argument("--run-worker")
    ns = parser.parse_args()
    RUNTIME.mkdir(parents=True, exist_ok=True)
    with LOCK.open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        if ns.heartbeat:
            heartbeat(ns.heartbeat)
        elif ns.run_worker:
            run_worker(ns.run_worker)
        else:
            once()


if __name__ == "__main__":
    main()
