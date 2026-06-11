#!/usr/bin/env python3
"""Create a clean ScholarPad source ZIP for transfer to macOS."""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path

sys.dont_write_bytecode = True

from audit_project import audit


EXCLUDED_PARTS = {
    ".git",
    ".build",
    "DerivedData",
    "__pycache__",
    "xcuserdata",
    "ScholarPad.xcodeproj",
}
EXCLUDED_SUFFIXES = {".pyc", ".xcuserstate"}


def included(path: Path, root: Path, output: Path) -> bool:
    resolved = path.resolve()
    if resolved == output.resolve():
        return False
    relative = path.relative_to(root)
    return not any(part in EXCLUDED_PARTS for part in relative.parts) and path.suffix not in EXCLUDED_SUFFIXES


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=root.parent / "ScholarPad-source.zip",
        help="Output ZIP path",
    )
    parser.add_argument("--skip-audit", action="store_true", help="Package without running the source audit")
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    if not args.skip_audit and audit(root, build=False) != 0:
        return 1

    files = [path for path in root.rglob("*") if path.is_file() and included(path, root, output)]
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(files):
            archive.write(path, Path(root.name) / path.relative_to(root))

    print(f"Created {output} with {len(files)} files ({output.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
