#!/usr/bin/env python3
"""Validate a ScholarPad chapters.json file using only the Python standard library."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


QUESTION_TYPES = ("single_choice", "multiple_choice", "true_false", "short_answer")
RESOURCE_TYPES = {"video", "audio", "document", "image", "link"}


def require(value: Any, expected: type, path: str, errors: list[str]) -> bool:
    if not isinstance(value, expected):
        errors.append(f"{path}: expected {expected.__name__}, got {type(value).__name__}")
        return False
    return True


def validate(path: Path) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    try:
        root = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return [f"Unable to read JSON: {exc}"], {}

    if not require(root, dict, "$", errors):
        return errors, {}

    if "chapters" not in root and "chapter_id" in root:
        root = {"chapters": [root]}

    for metadata_key in ("course_id", "course_title", "course_subtitle", "course_subject"):
        if metadata_key in root:
            require(root.get(metadata_key), str, f"$.{metadata_key}", errors)
    if "course_accent" in root and root.get("course_accent") not in {"indigo", "cyan", "coral", "violet", "mint"}:
        errors.append("$.course_accent: unsupported accent")

    chapters = root.get("chapters")
    if not require(chapters, list, "$.chapters", errors):
        return errors, {}

    actual_questions = 0
    actual_modules = 0
    chapter_ids: set[int] = set()

    for chapter_index, chapter in enumerate(chapters):
        base = f"$.chapters[{chapter_index}]"
        if not require(chapter, dict, base, errors):
            continue

        chapter_id = chapter.get("chapter_id")
        if require(chapter_id, int, f"{base}.chapter_id", errors):
            if chapter_id in chapter_ids:
                errors.append(f"{base}.chapter_id: duplicate id {chapter_id}")
            chapter_ids.add(chapter_id)
        if "chapter_title" in chapter:
            require(chapter.get("chapter_title"), str, f"{base}.chapter_title", errors)

        points = chapter.get("knowledge_points", [])
        if require(points, list, f"{base}.knowledge_points", errors):
            actual_modules += len(points)
            for point_index, point in enumerate(points):
                point_path = f"{base}.knowledge_points[{point_index}]"
                if not require(point, dict, point_path, errors):
                    continue
                require(point.get("title"), str, f"{point_path}.title", errors)
                if "description" in point:
                    require(point.get("description"), str, f"{point_path}.description", errors)
                if "sub_points" in point:
                    require(point.get("sub_points"), list, f"{point_path}.sub_points", errors)
                resources = point.get("resources", [])
                if require(resources, list, f"{point_path}.resources", errors):
                    resource_ids: set[str] = set()
                    for resource_index, resource in enumerate(resources):
                        resource_path = f"{point_path}.resources[{resource_index}]"
                        if not require(resource, dict, resource_path, errors):
                            continue
                        if resource.get("kind") not in RESOURCE_TYPES:
                            errors.append(f"{resource_path}.kind: unsupported resource type")
                        for key in ("id", "title", "url"):
                            require(resource.get(key), str, f"{resource_path}.{key}", errors)
                        resource_id = resource.get("id")
                        if isinstance(resource_id, str):
                            if resource_id in resource_ids:
                                errors.append(f"{resource_path}.id: duplicate id {resource_id!r}")
                            resource_ids.add(resource_id)
                        resource_url = resource.get("url")
                        if isinstance(resource_url, str):
                            parsed_url = urlparse(resource_url)
                            if parsed_url.scheme.lower() != "https" or not parsed_url.netloc:
                                errors.append(f"{resource_path}.url: expected HTTPS URL with host")

        questions = chapter.get("questions", {})
        if require(questions, dict, f"{base}.questions", errors):
            chapter_question_count = 0
            for question_type in QUESTION_TYPES:
                items = questions.get(question_type, [])
                if not require(items, list, f"{base}.questions.{question_type}", errors):
                    continue
                chapter_question_count += len(items)
                question_ids: set[int] = set()
                for question_index, question in enumerate(items):
                    question_path = f"{base}.questions.{question_type}[{question_index}]"
                    if not require(question, dict, question_path, errors):
                        continue
                    question_id = question.get("id")
                    if require(question_id, int, f"{question_path}.id", errors):
                        if question_id in question_ids:
                            errors.append(f"{question_path}.id: duplicate id {question_id}")
                        question_ids.add(question_id)
                    require(question.get("question"), str, f"{question_path}.question", errors)
                    if "answer" in question:
                        require(question.get("answer"), str, f"{question_path}.answer", errors)
                    if "explanation" in question:
                        require(question.get("explanation"), str, f"{question_path}.explanation", errors)
                    if question.get("type") != question_type:
                        errors.append(f"{question_path}.type: expected {question_type!r}")
            actual_questions += chapter_question_count

            stats = chapter.get("stats")
            if stats is not None and not require(stats, dict, f"{base}.stats", errors):
                stats = None
            if stats is not None and "total_questions" in stats and stats.get("total_questions") != chapter_question_count:
                errors.append(f"{base}.stats.total_questions: count does not match questions")
            if stats is not None and "knowledge_modules" in stats and stats.get("knowledge_modules") != len(points or []):
                errors.append(f"{base}.stats.knowledge_modules: count does not match knowledge_points")

    if "total_chapters" in root and root.get("total_chapters") != len(chapters):
        errors.append("$.total_chapters: count does not match chapters")
    if "total_questions" in root and root.get("total_questions") != actual_questions:
        errors.append("$.total_questions: count does not match questions")
    if "total_kp_modules" in root and root.get("total_kp_modules") != actual_modules:
        errors.append("$.total_kp_modules: count does not match knowledge_points")

    return errors, {
        "chapters": len(chapters),
        "questions": actual_questions,
        "knowledge_modules": actual_modules,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="Path to chapters.json")
    args = parser.parse_args()

    errors, stats = validate(args.path)
    if errors:
        print("Course validation failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "Course validation passed: "
        f"{stats['chapters']} chapters, "
        f"{stats['knowledge_modules']} knowledge modules, "
        f"{stats['questions']} questions"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
