#!/usr/bin/env python3
"""Line-coverage report for the critical Balance code.

Usage (after `flutter test --coverage`):
    python3 tools/check_coverage.py [--lcov coverage/lcov.info] [--min 70]

"Critical code" is the domain rules and the view-models that drive them
(Rev7 13.5 asks for at least 70% line coverage there). Generated files and
widgets are excluded on purpose; widget tests are evidence of behaviour, not of
line coverage. Exit status is 1 when the combined figure is below --min, so CI
can gate on it. Uses only the Python standard library.
"""
import argparse
import re
import sys

CRITICAL = (
    re.compile(r"^lib/domain/"),
    re.compile(r"^lib/features/[^/]+/[^/]+_view_model\.dart$"),
)
EXCLUDED = (re.compile(r"\.g\.dart$"), re.compile(r"\.freezed\.dart$"))


def parse(path):
    """Yield (file, found, hit) for every record of an lcov file."""
    name, found, hit = None, 0, 0
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith("SF:"):
                name = line[3:].replace("\\", "/")
                found = hit = 0
            elif line.startswith("DA:"):
                _, count = line[3:].split(",")[:2]
                found += 1
                hit += 1 if int(count) > 0 else 0
            elif line == "end_of_record" and name is not None:
                yield name, found, hit
                name = None


def is_critical(name):
    if any(p.search(name) for p in EXCLUDED):
        return False
    return any(p.search(name) for p in CRITICAL)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lcov", default="coverage/lcov.info")
    parser.add_argument("--min", type=float, default=70.0)
    args = parser.parse_args()

    try:
        rows = [r for r in parse(args.lcov) if is_critical(r[0]) and r[1] > 0]
    except FileNotFoundError:
        print(f"{args.lcov} not found. Run `flutter test --coverage` first.")
        return 2
    if not rows:
        print("No critical files found in the lcov report.")
        return 2

    rows.sort(key=lambda r: r[2] / r[1])
    print(f"{'file':<62} {'lines':>6} {'hit':>6} {'cover':>7}")
    for name, found, hit in rows:
        print(f"{name:<62} {found:>6} {hit:>6} {hit / found * 100:>6.1f}%")
    found = sum(r[1] for r in rows)
    hit = sum(r[2] for r in rows)
    percent = hit / found * 100
    print(f"\nCritical code: {hit}/{found} lines = {percent:.1f}% "
          f"(required {args.min:.0f}%)")
    return 0 if percent + 1e-9 >= args.min else 1


if __name__ == "__main__":
    sys.exit(main())
