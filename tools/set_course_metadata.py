#!/usr/bin/env python3
"""Add stable ScholarPad course metadata to a generated chapters.json file."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


ACCENTS = ("indigo", "cyan", "coral", "violet", "mint")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="Path to chapters.json")
    parser.add_argument("--id", required=True, help="Stable unique course ID")
    parser.add_argument("--title", required=True, help="Course display title")
    parser.add_argument("--subtitle", help="Course subtitle")
    parser.add_argument("--subject", help="Course category")
    parser.add_argument("--accent", choices=ACCENTS, default="indigo", help="Course theme color")
    args = parser.parse_args()

    try:
        data = json.loads(args.path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"Unable to read course JSON: {exc}", file=sys.stderr)
        return 1

    if not isinstance(data, dict) or not isinstance(data.get("chapters"), list):
        print("Course JSON must be an object containing a chapters array.", file=sys.stderr)
        return 1

    data["course_id"] = args.id.strip()
    data["course_title"] = args.title.strip()
    data["course_accent"] = args.accent
    if args.subtitle:
        data["course_subtitle"] = args.subtitle.strip()
    if args.subject:
        data["course_subject"] = args.subject.strip()

    temporary = args.path.with_suffix(args.path.suffix + ".tmp")
    try:
        temporary.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        os.replace(temporary, args.path)
    except OSError as exc:
        print(f"Unable to write course JSON: {exc}", file=sys.stderr)
        return 1

    print(f"Updated metadata for {args.path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

