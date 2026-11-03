"""Hit a URL in a tight loop for N seconds and count failures: measures availability during a rollout."""

import json
import sys
import time
import urllib.request


def main(url: str, seconds: float) -> None:
    ok = failed = 0
    errors: dict[str, int] = {}
    lat = []
    end = time.time() + seconds
    while time.time() < end:
        t = time.perf_counter()
        try:
            with urllib.request.urlopen(url, timeout=5) as r:
                r.read()
            ok += 1
            lat.append((time.perf_counter() - t) * 1000)
        except Exception as e:  # any error during the rollout counts as downtime
            failed += 1
            errors[type(e).__name__] = errors.get(type(e).__name__, 0) + 1
        time.sleep(0.1)
    lat.sort()
    p95 = round(lat[int(0.95 * len(lat))], 1) if lat else None
    print(json.dumps({"requests": ok + failed, "failed": failed, "errors": errors, "p95_ms": p95}))


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]))
