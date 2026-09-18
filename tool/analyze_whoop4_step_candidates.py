#!/usr/bin/env python3
"""Rank possible persistent counters in an OpenStrap WHOOP 4 database export.

This is a research aid, not a decoder. It reads the database in SQLite
read-only mode and never sends commands to a band. A candidate only becomes a
step counter after it is validated against independent, time-aligned walks.
"""

from __future__ import annotations

import argparse
import sqlite3
from collections import Counter
from pathlib import Path
from typing import Iterable


def _values(frames: Iterable[bytes], offset: int, width: int) -> list[int]:
    return [int.from_bytes(frame[offset : offset + width], "little") for frame in frames]


def _candidate_rows(frames: list[bytes]) -> list[tuple[float, float, float, int, int, int, int, int, int]]:
    """Find byte ranges that look counter-like without assigning a meaning."""
    rows = []
    for width in (1, 2, 4):
        for offset in range(len(frames[0]) - width + 1):
            values = _values(frames, offset, width)
            deltas = [right - left for left, right in zip(values, values[1:])]
            nondecreasing = sum(delta >= 0 for delta in deltas) / len(deltas)
            changed = sum(delta != 0 for delta in deltas) / len(deltas)
            small_forward = sum(0 <= delta <= 20 for delta in deltas) / len(deltas)
            # A counter is mostly non-decreasing and changes occasionally. This
            # deliberately does not require a step-shaped rate: timestamps and
            # packet counters should be reported too, then ruled out explicitly.
            if nondecreasing >= 0.995 and changed >= 0.01:
                rows.append(
                    (
                        nondecreasing,
                        small_forward,
                        changed,
                        width,
                        offset,
                        values[0],
                        values[-1],
                        min(deltas),
                        max(deltas),
                    )
                )
    return sorted(rows, reverse=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", type=Path, help="OpenStrap .db export")
    args = parser.parse_args()
    database = args.database.resolve()
    connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
    cursor = connection.cursor()

    rows = cursor.execute(
        """
        SELECT counter, hex FROM raw_archive
        WHERE reason = 'undecodable_rec_v25'
        ORDER BY counter
        """
    ).fetchall()
    if not rows:
        raise SystemExit("No archived WHOOP 4 v25 records found.")

    frames = [bytes.fromhex(hex_value) for _, hex_value in rows]
    lengths = Counter(map(len, frames))
    if len(lengths) != 1:
        raise SystemExit(f"Mixed frame lengths are not comparable: {dict(lengths)}")

    print(f"Read-only scan: {database.name}")
    print(f"v25 frames: {len(frames)}; inner length: {len(frames[0])} bytes")
    print(f"record-counter range: {rows[0][0]} .. {rows[-1][0]}")
    print("\nCounter-like byte ranges (little-endian):")
    print("nondec  small+  changed  width  offset  first  last  min_d  max_d")
    for candidate in _candidate_rows(frames)[:30]:
        nondec, small, changed, width, offset, first, last, minimum, maximum = candidate
        print(
            f"{nondec:6.3f}  {small:6.3f}  {changed:7.3f}"
            f"  {width:5d}  {offset:6d}  {first:5d}  {last:5d}"
            f"  {minimum:4d}  {maximum:4d}"
        )


if __name__ == "__main__":
    main()
