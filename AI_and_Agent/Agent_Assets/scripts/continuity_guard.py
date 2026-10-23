#!/usr/bin/env python3
"""Client-independent active-project continuity guard.

This program is run by cron, not by an AI client. It catches an
active project left without its expected tmux job even when a client lacks a
lifecycle-hook trust UI. It reports an anomaly; it never starts, kills, or
changes an analysis job.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pwd
import subprocess
import sys
import time
from pathlib import Path


ASSETS = Path("/home/gao/Utilities/AI_and_Agent/Agent_Assets")
sys.path.insert(0, str(ASSETS / "hooks/core"))
from continuity_state import continuity_violation


STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "agent-assets"
DEDUP_FILE = STATE_DIR / "continuity_guard.json"
ALERT_INTERVAL_SECONDS = 30 * 60
MAILER = Path(os.environ.get(
    "CONTINUITY_GUARD_MAILER",
    "/home/gao/Utilities/Server/monitoring_alerting/wd_sendmail.py",
))


def load_dedup() -> dict:
    try:
        return json.loads(DEDUP_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def save_dedup(data: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    DEDUP_FILE.write_text(json.dumps(data, sort_keys=True) + "\n", encoding="utf-8")


def alert_ttys(message: str) -> int:
    """Use the established ps-based tty broadcast path; never use `who`."""
    user = pwd.getpwuid(os.getuid()).pw_name
    result = subprocess.run(
        ["ps", "-eo", "tty=", "-u", user], text=True, capture_output=True, check=False
    )
    delivered = 0
    for tty in sorted({line.strip() for line in result.stdout.splitlines() if line.strip().startswith("pts/")}):
        target = Path("/dev") / tty
        try:
            with target.open("w", encoding="utf-8") as handle:
                handle.write(f"\n⚠️  {message}\n")
            delivered += 1
        except OSError:
            continue
    return delivered


def alert_email(message: str) -> str:
    """Send a serious unattended-project alert via the established SMTP helper."""
    if not MAILER.is_file():
        return "mailer_missing"
    try:
        result = subprocess.run(
            [str(MAILER), "🚨 [SEVERE] Active analysis project is unattended", "-"],
            input=message + "\n\nThe project remains marked active but its expected tmux session is absent.\n",
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=45,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return f"mailer_error={type(exc).__name__}"
    return f"email_exit={result.returncode}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true", help="required by the systemd one-shot unit")
    parser.add_argument("--no-tty", action="store_true", help="test-only: do not write to terminals")
    args = parser.parse_args()

    violation = continuity_violation()
    if not violation:
        print("CONTINUITY_GUARD_OK: no active project is missing its expected tmux session")
        return

    now = time.time()
    fingerprint = hashlib.sha256(violation.encode("utf-8")).hexdigest()
    dedup = load_dedup()
    try:
        last_alert = float(dedup.get("last_alert_epoch", 0))
    except (TypeError, ValueError):
        last_alert = 0
    should_alert = (
        dedup.get("fingerprint") != fingerprint
        or now - last_alert >= ALERT_INTERVAL_SECONDS
    )
    message = f"[SEVERE Agent project continuity] {violation}"
    delivered = alert_ttys(message) if should_alert and not args.no_tty else 0
    email_result = alert_email(message) if should_alert else "not_attempted"
    if should_alert:
        save_dedup({"fingerprint": fingerprint, "last_alert_epoch": now})
    print(
        "CONTINUITY_GUARD_ALERT: "
        f"alerted={should_alert} tty_recipients={delivered} {email_result} {violation}"
    )


if __name__ == "__main__":
    main()
