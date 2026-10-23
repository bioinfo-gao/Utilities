#!/usr/bin/env python3
"""Antigravity Stop-hook adapter for the shared continuity evaluator."""
from __future__ import annotations

import json
import sys
from pathlib import Path


CORE = Path("/home/gao/Utilities/AI_and_Agent/Agent_Assets/hooks/core")
sys.path.insert(0, str(CORE))
from continuity_state import continuity_violation


def main() -> None:
    try:
        json.load(sys.stdin)
    except json.JSONDecodeError:
        pass
    violation = continuity_violation()
    if violation:
        # Antigravity's Stop protocol uses "continue" to prevent termination.
        print(json.dumps({"decision": "continue", "reason": violation}, ensure_ascii=False))


if __name__ == "__main__":
    main()
