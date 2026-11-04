"""CI quality gate: fail the pipeline if retrieval quality drops below the thresholds measured in step 15.

A container build that "works" but silently retrieves worse (wrong model, broken index, changed chunking)
is the failure mode unit tests don't catch, so the gate runs the real retrieval eval against the deployed stack.
"""

import json
import sys
from pathlib import Path

# step 15 measured 0.968 / 0.992 (dense / rerank evidence@5): a little head-room for noise, none for a regression
THRESHOLDS = {"dense": 0.95, "rerank": 0.98}


def main(path: str) -> None:
    res = json.loads(Path(path).read_text())["retrieval"]["section"]
    failed = False
    for mode, minimum in THRESHOLDS.items():
        got = res[mode]["evidence@5"]
        ok = got >= minimum
        failed |= not ok
        print(f"{'PASS' if ok else 'FAIL'} {mode:7s} evidence@5 = {got:.3f} (minimum {minimum})")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main(sys.argv[1])
