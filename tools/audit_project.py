#!/usr/bin/env python3
"""Audit ScholarPad source delivery and optionally compile it on macOS."""

from __future__ import annotations

import argparse
import json
import platform
import plistlib
import shutil
import struct
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True

from validate_course import validate


REQUIRED_FILES = (
    "project.yml",
    "README.md",
    "Docs/COURSE_FORMAT.md",
    "Docs/catalog.example.json",
    "ScholarPad/App/ScholarPadApp.swift",
    "ScholarPad/App/RootView.swift",
    "ScholarPad/Models/CourseModels.swift",
    "ScholarPad/Models/LearningModels.swift",
    "ScholarPad/Services/AppModel.swift",
    "ScholarPad/Services/ContentRepository.swift",
    "ScholarPad/Services/CourseValidator.swift",
    "ScholarPad/Services/QuestionEvaluator.swift",
    "ScholarPad/Services/ResourceDownloadService.swift",
    "ScholarPad/Services/ReviewReminderService.swift",
    "ScholarPad/Services/LearningBackupService.swift",
    "ScholarPad/Resources/chapters.json",
    "ScholarPad/Resources/PrivacyInfo.xcprivacy",
    "ScholarPad/Resources/Assets.xcassets/AppIcon.appiconset/ScholarPadIcon.png",
    "ScholarPadTests/ContentDecoderTests.swift",
    "tools/parse_to_json.py",
    ".github/workflows/ios.yml",
)

REQUIRED_FEATURE_FILES = (
    "ScholarPad/Features/Dashboard/DashboardView.swift",
    "ScholarPad/Features/Courses/CourseCatalogView.swift",
    "ScholarPad/Features/Courses/OnlineLibraryView.swift",
    "ScholarPad/Features/Courses/LessonReaderView.swift",
    "ScholarPad/Features/Courses/ResourceViewerView.swift",
    "ScholarPad/Features/Practice/PracticeHubView.swift",
    "ScholarPad/Features/Practice/QuizSessionView.swift",
    "ScholarPad/Features/Library/GlobalSearchView.swift",
    "ScholarPad/Features/Library/NotesView.swift",
    "ScholarPad/Features/Library/SavedItemsView.swift",
    "ScholarPad/Features/Progress/LearningProgressView.swift",
    "ScholarPad/Features/Settings/SettingsView.swift",
    "ScholarPad/Features/Settings/LearningBackupDocument.swift",
)

FORBIDDEN_SWIFT_TOKENS = ("TO" "DO", "FIX" "ME", "fatal" "Error(", "try" "!", " as" "! ")


def check_png_icon(path: Path) -> list[str]:
    errors: list[str] = []
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return [f"{path}: invalid PNG icon"]
    width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])
    if (width, height) != (1024, 1024):
        errors.append(f"{path}: app icon must be 1024x1024, got {width}x{height}")
    if bit_depth != 8:
        errors.append(f"{path}: app icon must use 8-bit channels")
    if color_type in {4, 6}:
        errors.append(f"{path}: app icon must not contain an alpha channel")
    return errors


def check_swift_sources(root: Path) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    files = sorted(root.rglob("*.swift"))
    lines = 0
    for path in files:
        text = path.read_text(encoding="utf-8")
        lines += text.count("\n") + 1
        for opener, closer, label in (("{", "}", "braces"), ("(", ")", "parentheses"), ("[", "]", "brackets")):
            if text.count(opener) != text.count(closer):
                errors.append(f"{path}: unbalanced {label}")
        for token in FORBIDDEN_SWIFT_TOKENS:
            if token in text:
                errors.append(f"{path}: forbidden token {token!r}")
    return errors, {"swift_files": len(files), "swift_lines": lines}


def run(command: list[str], cwd: Path) -> None:
    print("+", " ".join(command))
    subprocess.run(command, cwd=cwd, check=True)


def compile_on_macos(root: Path) -> list[str]:
    errors: list[str] = []
    if platform.system() != "Darwin":
        return ["--build requires macOS with Xcode"]
    if not shutil.which("xcodebuild"):
        return ["xcodebuild is unavailable"]
    if not shutil.which("xcodegen"):
        return ["xcodegen is unavailable; install it with: brew install xcodegen"]

    try:
        run(["xcodegen", "generate"], root)
        run(
            [
                "xcodebuild",
                "-project",
                "ScholarPad.xcodeproj",
                "-scheme",
                "ScholarPad",
                "-configuration",
                "Debug",
                "-destination",
                "generic/platform=iOS Simulator",
                "CODE_SIGNING_ALLOWED=NO",
                "build",
            ],
            root,
        )
    except subprocess.CalledProcessError as exc:
        errors.append(f"Xcode build failed with exit code {exc.returncode}")
    return errors


def audit(root: Path, build: bool) -> int:
    errors: list[str] = []

    for relative in REQUIRED_FILES + REQUIRED_FEATURE_FILES:
        if not (root / relative).is_file():
            errors.append(f"Missing required file: {relative}")

    for path in root.rglob("*.json"):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            errors.append(f"{path}: invalid JSON: {exc}")

    course_errors, course_stats = validate(root / "ScholarPad/Resources/chapters.json")
    errors.extend(f"chapters.json: {error}" for error in course_errors)

    catalog_path = root / "Docs/catalog.example.json"
    if catalog_path.is_file():
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        descriptors = catalog.get("courses", [])
        descriptor_ids = [descriptor.get("id") for descriptor in descriptors if isinstance(descriptor, dict)]
        if len(descriptor_ids) != len(set(descriptor_ids)):
            errors.append("catalog.example.json: duplicate course IDs")
        for descriptor in descriptors:
            if isinstance(descriptor, dict) and not str(descriptor.get("course_url", "")).startswith("https://"):
                errors.append("catalog.example.json: course_url must use HTTPS")

    icon = root / "ScholarPad/Resources/Assets.xcassets/AppIcon.appiconset/ScholarPadIcon.png"
    if icon.is_file():
        errors.extend(check_png_icon(icon))

    privacy_path = root / "ScholarPad/Resources/PrivacyInfo.xcprivacy"
    if privacy_path.is_file():
        try:
            privacy = plistlib.loads(privacy_path.read_bytes())
            accessed = privacy.get("NSPrivacyAccessedAPITypes", [])
            reasons = {
                reason
                for entry in accessed
                if entry.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
                for reason in entry.get("NSPrivacyAccessedAPITypeReasons", [])
            }
            if "CA92.1" not in reasons:
                errors.append("PrivacyInfo.xcprivacy: missing UserDefaults reason CA92.1")
            if privacy.get("NSPrivacyTracking") is not False:
                errors.append("PrivacyInfo.xcprivacy: expected NSPrivacyTracking=false")
        except (OSError, plistlib.InvalidFileException) as exc:
            errors.append(f"PrivacyInfo.xcprivacy: invalid privacy manifest: {exc}")

    swift_errors, swift_stats = check_swift_sources(root)
    errors.extend(swift_errors)

    for path in root.rglob("*"):
        if path.name == "__pycache__" or path.suffix == ".pyc":
            errors.append(f"Generated cache must not be delivered: {path}")

    if build:
        errors.extend(compile_on_macos(root))

    print(
        "ScholarPad audit summary: "
        f"{swift_stats['swift_files']} Swift files, "
        f"{swift_stats['swift_lines']} Swift lines, "
        f"{course_stats.get('chapters', 0)} chapters, "
        f"{course_stats.get('questions', 0)} questions"
    )
    if errors:
        print("Audit failed:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("Audit passed.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true", help="Generate and compile the Xcode project on macOS")
    args = parser.parse_args()
    return audit(Path(__file__).resolve().parent.parent, args.build)


if __name__ == "__main__":
    sys.exit(main())
