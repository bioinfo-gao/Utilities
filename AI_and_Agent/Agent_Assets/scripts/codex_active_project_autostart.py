#!/usr/bin/env python3
"""Resume a registered active project only after its configured delay.

This controller does not invent project state.  `active_projects.json` remains
the sole active-project SSOT; each project names the one agent that owns it, and
each agent has its own companion configuration, lock, and audit trail so that
Codex and Claude Code projects never resume each other's sessions.

Usage-limit retry policy (user directive 2026-10-25): once a usage limit is
seen, retry at the parsed reset time plus a short grace when the message gives
one, otherwise (and as fallback) at 3 h, 4 h and 5 h after the limit.  When the
last scheduled attempt still hits the limit, mark the project blocked and email
the user instead of retrying indefinitely.
"""
from __future__ import annotations

import argparse
import fcntl
import glob
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


ASSETS = Path("/home/gao/Utilities/AI_and_Agent/Agent_Assets")
RUNTIME = ASSETS / "runtime"
ACTIVE = RUNTIME / "active_projects.json"
MAILER = Path("/home/gao/Utilities/Server/monitoring_alerting/wd_sendmail.py")
AGENTS = {
    "codex": "codex_active_project_autostart",
    "claude_code": "claude_code_active_project_autostart",
}
# Selected by --agent; defaults keep the original Codex paths.
CONFIG = RUNTIME / "codex_active_project_autostart.json"
LOCK = RUNTIME / "codex_active_project_autostart.lock"
LOG_DIR = RUNTIME / "codex_active_project_autostart_logs"
AGENT = "codex"

USAGE_RE = re.compile(
    r"usage limit reached|hit your (?:usage )?limit|limit reached\s*[∙·•]\s*resets|(?:usage|rate)[ _-]?limit", re.I
)
MONTHS = {m: i for i, m in enumerate(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], 1)}
EPOCH_RE = re.compile(r"limit reached\|(\d{10,13})", re.I)
CLOCK_RE = re.compile(
    r"(?:resets|try again at)\s+(?:(?P<mon>[A-Za-z]{3})[a-z]*\s+(?P<day>\d{1,2})(?:st|nd|rd|th)?,?\s+(?:at\s+)?)?"
    r"(?P<h>\d{1,2})(?::(?P<m>\d{2}))?\s*(?P<ap>[ap]\.?m\.?)(?:\s*\((?P<tz>[A-Za-z_]+/[A-Za-z_/+-]+|UTC)\))?",
    re.I,
)
RELATIVE_RE = re.compile(
    r"try again in\s+(?:(?P<d>\d+)\s*days?)?[\s,]*(?:(?P<h>\d+)\s*hours?)?[\s,]*(?:(?P<m>\d+)\s*min(?:ute)?s?)?", re.I
)


def select_agent(name: str) -> None:
    global CONFIG, LOCK, LOG_DIR, AGENT
    stem = AGENTS[name]
    AGENT = name
    CONFIG = RUNTIME / f"{stem}.json"
    LOCK = RUNTIME / f"{stem}.lock"
    LOG_DIR = RUNTIME / f"{stem}_logs"


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
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(path)


def tmux_live(name: str) -> bool:
    if not name:
        return False
    return subprocess.run(["tmux", "has-session", "-t", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def append_event(event: dict) -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    with (LOG_DIR / "controller_events.jsonl").open("a") as handle:
        handle.write(json.dumps({"agent": AGENT, **event}, ensure_ascii=False) + "\n")


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


def coverage_gaps(projects: list, entries: list, agent: str) -> tuple[list, list]:
    """Return (this agent's running projects not armed, running projects owned by no known agent)."""
    running = [p for p in projects if p.get("status") == "running"]
    unassigned = sorted(p.get("id", "") for p in running if p.get("agent") not in AGENTS)
    mine = {p.get("id") for p in running if p.get("agent") == agent}
    armed = {e.get("active_project_id") for e in entries if e.get("status") == "armed"}
    return sorted(mine - armed), unassigned


def require_running_project_coverage(config: dict) -> None:
    """Fail loudly rather than silently omitting any currently running project."""
    missing, unassigned = coverage_gaps(load(ACTIVE).get("projects", []), config.get("entries", []), AGENT)
    if missing or unassigned:
        append_event({"at": stamp(), "event": "coverage_failure", "missing_running_projects": missing, "unassigned_running_projects": unassigned})
        raise RuntimeError(
            f"Autostart ({AGENT}) coverage failure: not armed={missing}; running without a known 'agent' owner={unassigned}"
        )


def heartbeat(project_id: str) -> None:
    config = load(CONFIG)
    entry = entry_for(config, project_id)
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "explicit_agent_heartbeat"
    save(CONFIG, config)
    append_event({"at": stamp(), "event": "heartbeat", "project": project_id})


# ---------- usage-limit message parsing ----------

def _local_tz(name: str | None):
    if name:
        try:
            return timezone.utc if name.upper() == "UTC" else ZoneInfo(name)
        except ZoneInfoNotFoundError:
            pass
    return datetime.now().astimezone().tzinfo


def parse_reset(text: str, reference: datetime) -> datetime | None:
    """Best-effort reset time from a usage-limit message; None when not stated."""
    match = EPOCH_RE.search(text)
    if match:
        value = int(match.group(1))
        return datetime.fromtimestamp(value / 1000 if value > 10**12 else value, timezone.utc)
    match = CLOCK_RE.search(text)
    if match:
        tz = _local_tz(match.group("tz"))
        hour = int(match.group("h")) % 12 + (12 if match.group("ap").lower().startswith("p") else 0)
        minute = int(match.group("m") or 0)
        local_ref = reference.astimezone(tz)
        if match.group("mon") and match.group("mon")[:3].lower() in MONTHS:
            candidate = local_ref.replace(month=MONTHS[match.group("mon")[:3].lower()], day=int(match.group("day")),
                                          hour=hour, minute=minute, second=0, microsecond=0)
            if candidate < local_ref - timedelta(days=1):
                candidate = candidate.replace(year=candidate.year + 1)
        else:
            candidate = local_ref.replace(hour=hour, minute=minute, second=0, microsecond=0)
            if candidate <= local_ref:
                candidate += timedelta(days=1)
        return candidate.astimezone(timezone.utc)
    match = RELATIVE_RE.search(text)
    if match and any(match.group(k) for k in ("d", "h", "m")):
        return reference + timedelta(days=int(match.group("d") or 0), hours=int(match.group("h") or 0),
                                     minutes=int(match.group("m") or 0))
    return None


def _is_error_row(row: dict) -> bool:
    if row.get("isApiErrorMessage") or row.get("is_error") or row.get("error"):
        return True
    payload = row.get("payload") if isinstance(row.get("payload"), dict) else {}
    return bool({str(row.get("type", "")), str(payload.get("type", ""))} & {"error", "stream_error", "turn.failed"})


def find_usage_limit(lines: list[str], fallback_time: datetime) -> tuple[datetime, str] | None:
    """Last usage-limit error in transcript/worker output as (time, text).

    Only error rows count, so an agent merely discussing limits is not a hit;
    non-JSON lines (CLI stderr) are treated as errors.
    """
    found = None
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            row = None
        if isinstance(row, dict):
            if not _is_error_row(row):
                continue
            text = json.dumps(row, ensure_ascii=False)
            when = parse_time(str(row.get("timestamp", ""))) or fallback_time
        else:
            text, when = line, fallback_time
        if USAGE_RE.search(text):
            found = (when, text)
    return found


def session_transcript(entry: dict) -> Path | None:
    if entry.get("session_transcript"):
        return Path(entry["session_transcript"])
    if entry.get("codex_session_id"):
        hits = sorted(glob.glob(str(Path.home() / f".codex/sessions/*/*/*/*{entry['codex_session_id']}.jsonl")))
        return Path(hits[-1]) if hits else None
    return None


def tail_lines(path: Path, limit_bytes: int = 400_000) -> list[str]:
    with path.open("rb") as handle:
        handle.seek(0, 2)
        size = handle.tell()
        handle.seek(max(0, size - limit_bytes))
        return handle.read().decode("utf-8", errors="replace").splitlines()[1 if size > limit_bytes else 0:]


# ---------- retry schedule ----------

def attempt_times(entry: dict) -> list[datetime]:
    start = parse_time(entry.get("usage_episode_started_at", ""))
    if not start:
        return []
    times = [start + timedelta(seconds=int(s)) for s in entry["usage_limit_retry_offsets_seconds"]]
    reset = parse_time(entry.get("usage_reset_at", ""))
    if reset:
        first = reset + timedelta(seconds=int(entry.get("reset_grace_seconds", 300)))
        times = [first] + [t for t in times if t > first]
    return sorted(times)


def next_attempt(entry: dict) -> datetime | None:
    last = parse_time(entry.get("usage_last_attempt_at", ""))
    for when in attempt_times(entry):
        if last is None or when > last:
            return when
    return None


def open_usage_episode(entry: dict, when: datetime, text: str) -> None:
    if not entry.get("usage_episode_started_at"):
        entry["usage_episode_started_at"] = stamp(when)
    reset = parse_reset(text, when)
    if reset:
        entry["usage_reset_at"] = stamp(reset)
    entry["last_usage_limit_at"] = stamp(when)
    entry["last_usage_limit_message"] = text[-500:]


def close_usage_episode(entry: dict) -> None:
    for key in ("usage_episode_started_at", "usage_reset_at", "usage_last_attempt_at"):
        entry[key] = ""


def exhaust(project_id: str, config: dict, entry: dict) -> None:
    """Last scheduled retry failed: stop retrying, mark blocked in the SSOT, email the user."""
    reason = (f"Usage limit persisted through every scheduled automatic retry ({AGENT}); "
              f"episode started {entry.get('usage_episode_started_at')}, last message: {entry.get('last_usage_limit_message', '')[-200:]}")
    entry["status"] = "exhausted"
    save(CONFIG, config)
    state = load(ACTIVE)
    for project in state.get("projects", []):
        if project.get("id") == project_id and project.get("status") == "running":
            project["status"] = "blocked"
            project["blocked_reason"] = reason
            project["blocking_question"] = "Usage-limit retries exhausted: resume manually, or re-arm autostart for this project?"
            project["last_verified_at"] = stamp()
    save(ACTIVE, state)
    mail = "mailer_missing"
    if MAILER.is_file():
        result = subprocess.run([str(MAILER), f"🚨 [SEVERE] {project_id}: automatic resume exhausted ({AGENT})", "-"],
                                input=reason + "\n", text=True, capture_output=True, timeout=45, check=False)
        mail = f"email_exit={result.returncode}"
    append_event({"at": stamp(), "event": "usage_retries_exhausted", "project": project_id, "mail": mail})


def choose_trigger(entry: dict, active: dict, has_live_session: bool) -> tuple[str, datetime] | None:
    if active.get("status") != "running" or entry.get("status") != "armed":
        return None
    if entry.get("project_root") != active.get("project_root"):
        raise ValueError("configured project root does not match active-project SSOT")
    if entry.get("last_worker_result") == "non_usage_failure":
        return None
    if has_live_session:
        return None
    if entry.get("usage_episode_started_at"):
        when = next_attempt(entry)
        return ("usage_limit_retry", when) if when else ("usage_retries_exhausted", now())
    missing_at = parse_time(entry.get("missing_tmux_observed_at", ""))
    if missing_at:
        return "stale_active_fallback", missing_at + timedelta(seconds=int(entry["fallback_stale_seconds"]))
    return "observe_missing_tmux", now()


def worker_command(entry: dict) -> tuple[list[str], str]:
    if AGENT == "claude_code":
        return ([entry["claude_binary"], "-p", "--resume", entry["claude_session_id"], "--output-format", "stream-json",
                 "--verbose", "--permission-mode", entry.get("permission_mode", "auto"), entry["continuation_prompt"]],
                entry["session_cwd"])
    return ([entry["codex_binary"], "exec", "resume", "--json", entry["codex_session_id"], entry["continuation_prompt"]],
            entry["project_root"])


def launch(project_id: str, config: dict, entry: dict, trigger: str) -> None:
    token = now().strftime("%Y%m%dT%H%M%SZ")
    prefix = "codex" if AGENT == "codex" else "claude"
    session = f"{prefix}_autoresume_{project_id}_{token}"[:90]
    # tmux executes this same verified script; no shell interpolation of prompt/config occurs.
    command = ["tmux", "new-session", "-d", "-s", session, sys.executable, str(Path(__file__).resolve()),
               "--agent", AGENT, "--run-worker", project_id]
    subprocess.run(command, check=True)
    entry["last_launch_at"] = stamp()
    entry["last_worker_session"] = session
    entry["last_trigger"] = trigger
    if trigger == "usage_limit_retry":
        entry["usage_last_attempt_at"] = stamp()
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "autostart_launch"
    entry["missing_tmux_observed_at"] = ""
    save(CONFIG, config)
    append_event({"at": stamp(), "event": "worker_launched", "project": project_id, "tmux_session": session, "trigger": trigger})


def detect_session_limit(entry: dict) -> bool:
    """Open a usage episode from a limit hit inside the original interactive session."""
    path = session_transcript(entry)
    if not path or not path.is_file():
        return False
    hit = find_usage_limit(tail_lines(path), datetime.fromtimestamp(path.stat().st_mtime, timezone.utc))
    seen = parse_time(entry.get("last_usage_limit_at", ""))
    if not hit or (seen and hit[0] <= seen):
        return False
    open_usage_episode(entry, hit[0], hit[1])
    return True


def session_busy(entry: dict) -> bool:
    """Never resume a session that someone is still writing to."""
    path = session_transcript(entry)
    if not path or not path.is_file():
        return False
    idle = (now() - datetime.fromtimestamp(path.stat().st_mtime, timezone.utc)).total_seconds()
    return idle < int(entry.get("min_transcript_idle_seconds", 1200))


def once() -> None:
    config = load(CONFIG)
    require_running_project_coverage(config)
    for entry in config.get("entries", []):
        project_id = entry.get("active_project_id", "")
        active = active_for(project_id)
        if not active:
            append_event({"at": stamp(), "event": "configuration_error", "project": project_id, "reason": "active project not found"})
            continue
        if active.get("agent") != AGENT:
            append_event({"at": stamp(), "event": "configuration_error", "project": project_id,
                          "reason": f"project owned by agent {active.get('agent')!r}, not {AGENT!r}"})
            continue
        expected_live = tmux_live(active.get("expected_tmux_session", ""))
        worker_live = tmux_live(entry.get("last_worker_session", ""))
        if expected_live or worker_live:
            if entry.get("missing_tmux_observed_at"):
                entry["missing_tmux_observed_at"] = ""
                save(CONFIG, config)
                append_event({"at": stamp(), "event": "tmux_restored", "project": project_id})
            continue
        if entry.get("status") == "armed" and not entry.get("usage_episode_started_at") and detect_session_limit(entry):
            save(CONFIG, config)
            append_event({"at": stamp(), "event": "session_usage_limit_observed", "project": project_id,
                          "limit_at": entry["last_usage_limit_at"], "reset_at": entry.get("usage_reset_at", "")})
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
        if trigger == "usage_retries_exhausted":
            exhaust(project_id, config, entry)
            continue
        if now() < eligible_at:
            continue
        if session_busy(entry):
            append_event({"at": stamp(), "event": "launch_deferred_session_busy", "project": project_id, "trigger": trigger})
            continue
        launch(project_id, config, entry, trigger)


def run_worker(project_id: str) -> None:
    config = load(CONFIG)
    entry = entry_for(config, project_id)
    active = active_for(project_id)
    if not active or active.get("status") != "running" or active.get("agent") != AGENT:
        append_event({"at": stamp(), "event": "worker_cancelled", "project": project_id, "reason": "project not running for this agent"})
        return
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log = LOG_DIR / f"{project_id}_{now().strftime('%Y%m%dT%H%M%SZ')}.jsonl"
    entry["last_worker_started_at"] = stamp()
    entry["last_worker_log"] = str(log)
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "autostart_worker_started"
    save(CONFIG, config)
    command, cwd = worker_command(entry)
    with log.open("w") as handle:
        result = subprocess.run(command, cwd=cwd, stdout=handle, stderr=subprocess.STDOUT)
    hit = find_usage_limit(log.read_text(errors="replace").splitlines(), now())
    config = load(CONFIG)
    entry = entry_for(config, project_id)
    entry["last_worker_finished_at"] = stamp()
    entry["last_worker_exit_code"] = result.returncode
    entry["last_worker_session"] = ""
    entry["last_worker_result"] = "usage_limit_detected" if hit else ("completed_or_stopped" if result.returncode == 0 else "non_usage_failure")
    if hit:
        open_usage_episode(entry, hit[0], hit[1])
    else:
        close_usage_episode(entry)
    entry["last_agent_heartbeat"] = stamp()
    entry["last_agent_heartbeat_source"] = "autostart_worker_finished"
    save(CONFIG, config)
    append_event({"at": stamp(), "event": "worker_finished", "project": project_id, "exit_code": result.returncode,
                  "result": entry["last_worker_result"], "reset_at": entry.get("usage_reset_at", ""), "log": str(log)})
    if hit and next_attempt(entry) is None:
        exhaust(project_id, config, entry)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--agent", choices=sorted(AGENTS), default="codex")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--once", action="store_true")
    group.add_argument("--heartbeat")
    group.add_argument("--run-worker")
    ns = parser.parse_args()
    select_agent(ns.agent)
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
