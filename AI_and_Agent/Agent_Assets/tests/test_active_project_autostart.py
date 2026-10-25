#!/usr/bin/env python3
"""Tests for per-agent coverage, usage-limit parsing and the capped retry schedule."""
from __future__ import annotations

import importlib.util
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path


ROOT = Path("/home/gao/Utilities/AI_and_Agent/Agent_Assets")
spec = importlib.util.spec_from_file_location("autostart", ROOT / "scripts/codex_active_project_autostart.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

T0 = datetime(2026, 10, 25, 3, 0, tzinfo=timezone.utc)
H = timedelta(hours=1)

# Coverage is scoped per agent; an owner-less running project still fails loudly.
projects = [
    {"id": "A", "status": "running", "agent": "codex"},
    {"id": "B", "status": "running", "agent": "claude_code"},
    {"id": "C", "status": "complete", "agent": "codex"},
]
armed_a = [{"active_project_id": "A", "status": "armed"}]
assert m.coverage_gaps(projects, armed_a, "codex") == ([], [])
assert m.coverage_gaps(projects, [], "claude_code") == (["B"], [])
assert m.coverage_gaps(projects + [{"id": "D", "status": "running"}], armed_a, "codex") == ([], ["D"])

# Reset-time parsing.
assert m.parse_reset("Claude AI usage limit reached|1761400000", T0) == datetime.fromtimestamp(1761400000, timezone.utc)
got = m.parse_reset("5-hour limit reached ∙ resets 5am (America/New_York)", T0)  # T0 = 23:00 EDT
assert got == datetime(2026, 10, 25, 9, 0, tzinfo=timezone.utc), got
got = m.parse_reset("You've hit your limit · resets 11:30pm (UTC)", T0)
assert got == datetime(2026, 10, 25, 23, 30, tzinfo=timezone.utc), got
assert m.parse_reset("You've hit your usage limit. Try again in 2 hours 5 minutes.", T0) == T0 + timedelta(hours=2, minutes=5)
assert m.parse_reset("usage limit reached", T0) is None

# Only error rows count as a limit hit.
rows = [
    json.dumps({"type": "assistant", "timestamp": "2026-10-25T02:00:00Z", "message": {"content": "discussing usage limit policy"}}),
    json.dumps({"type": "assistant", "isApiErrorMessage": True, "timestamp": "2026-10-25T02:10:00Z",
                "message": {"content": [{"type": "text", "text": "You've hit your limit · resets 6am (UTC)"}]}}),
]
hit = m.find_usage_limit(rows, T0)
assert hit and hit[0] == datetime(2026, 10, 25, 2, 10, tzinfo=timezone.utc)
assert m.find_usage_limit(rows[:1], T0) is None

base = {"usage_limit_retry_offsets_seconds": [10800, 14400, 18000], "reset_grace_seconds": 300}

# No reset stated: 3 h, 4 h, 5 h, then exhausted.
e = dict(base, usage_episode_started_at=m.stamp(T0))
seen = []
while (n := m.next_attempt(e)) is not None:
    seen.append(n)
    e["usage_last_attempt_at"] = m.stamp(n)
assert seen == [T0 + 3 * H, T0 + 4 * H, T0 + 5 * H], seen

# Reset stated at +1 h: retry at reset+5 min first, then the 3/4/5 h fallbacks.
e = dict(base, usage_episode_started_at=m.stamp(T0), usage_reset_at=m.stamp(T0 + H))
assert m.attempt_times(e) == [T0 + H + timedelta(minutes=5), T0 + 3 * H, T0 + 4 * H, T0 + 5 * H]

# Reset at +4.5 h: fallbacks before the reset are pointless and dropped.
e = dict(base, usage_episode_started_at=m.stamp(T0), usage_reset_at=m.stamp(T0 + 4.5 * H))
assert m.attempt_times(e) == [T0 + 4.5 * H + timedelta(minutes=5), T0 + 5 * H]

# Weekly-style reset beyond 5 h: exactly one attempt, at the reset.
e = dict(base, usage_episode_started_at=m.stamp(T0), usage_reset_at=m.stamp(T0 + 50 * H))
assert m.attempt_times(e) == [T0 + 50 * H + timedelta(minutes=5)]

print("test_active_project_autostart: all assertions passed")
