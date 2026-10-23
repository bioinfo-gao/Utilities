#!/usr/bin/env python3
"""Claude Code Stop-hook adapter for the shared continuity evaluator."""
from __future__ import annotations

import json
import sys

from continuity_state import continuity_violation


def main() -> None:
    # Consume the native event so malformed stdin cannot leak into hook output.
    try:
        json.load(sys.stdin)
    except json.JSONDecodeError:
        pass
    violation = continuity_violation()
    if violation:
        print(json.dumps({"decision": "block", "reason": violation}, ensure_ascii=False))


if __name__ == "__main__":
    main()
