#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
教辅内容JSON解析器 v1.0
=================================
将 ocr_pipeline.py 输出的Markdown解析为结构化JSON，供APP开发直接使用。

输入：final_output.md（或 output/03_chapters/ 下的章节文件）
输出：
  output/json/chapters.json      ← 全书汇总（章节列表+题库）
  output/json/chapter_001.json   ← 每章独立JSON
  output/json/knowledge_only.json ← 仅知识点（学习模块）
  output/json/questions_only.json ← 仅题库（刷题模块）

用法:
  python parse_to_json.py --input output/final_output.md
  python parse_to_json.py --dir output/03_chapters
"""

import re
import json
import argparse
import logging
import sys
from pathlib import Path
from typing import List, Dict, Optional, Any

# ── 输出目录 ──────────────────────────────────────────
JSON_DIR = Path("output/json")
COURSE_METADATA: Dict[str, Any] = {}

# ── 日志 ──────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("parser")


# ╔══════════════════════════════════════════════════════╗
# ║                  核心解析逻辑                      ║
# ╚══════════════════════════════════════════════════════╝

def split_chapters(text: str) -> List[str]:
    """按 ===CHAPTER_START=== / ===CHAPTER_END=== 拆分章节块"""
    chunks: List[str] = []
    pattern = r'===CHAPTER_START===\s*(.*?)\s*===CHAPTER_END==='
    for m in re.finditer(pattern, text, re.DOTALL):
        chunk = m.group(1).strip()
        if chunk:
            chunks.append(chunk)

    if not chunks:
        # 回退：没有标记时，把整段当一个章节
        log.warning("未找到 CHAPTER_START/END 标记，将整段作为单一章节处理")
        chunks = [text.strip()]

    log.info(f"  检测到 {len(chunks)} 个章节块")
    return chunks


def parse_chapter_title(chapter_text: str) -> str:
    """提取 # 第X章 章节名称"""
    m = re.search(r'^#\s+(.+)', chapter_text, re.MULTILINE)
    if m:
        return m.group(1).strip()
    # 备用：匹配"第X章"
    m = re.search(r'第\s*\S+\s*章[^\n]*', chapter_text)
    return m.group().strip() if m else "未知章节"


def parse_knowledge_points(chapter_text: str) -> List[Dict]:
    """
    解析知识点部分（## 一、本章知识点 到下一个 ## 之间）
    返回结构化知识点列表
    """
    # 提取知识点区块
    m = re.search(
        r'##\s*一[、.．]?\s*本章知识点(.*?)(?=##\s*二[、.．]|\Z)',
        chapter_text, re.DOTALL
    )
    if not m:
        return []

    kp_text = m.group(1).strip()
    knowledge_points: List[Dict] = []
    current_module: Optional[Dict] = None

    for line in kp_text.splitlines():
        line_stripped = line.strip()
        if not line_stripped or line_stripped.startswith('---'):
            continue

        # 一级模块：- **模块名** 或 **模块名**：
        mod_match = re.match(r'^[-*]?\s*\*\*([^*]+)\*\*[：:：]?\s*(.*)', line_stripped)
        if mod_match and not line_stripped.startswith('  '):
            # 保存上一个模块
            if current_module:
                knowledge_points.append(current_module)
            current_module = {
                "title":       mod_match.group(1).strip(),
                "description": mod_match.group(2).strip(),
                "sub_points":  [],
            }
            continue

        # 子知识点：  - 内容
        if line_stripped.startswith('-') and current_module:
            sub_text = re.sub(r'^\s*[-*]\s*', '', line_stripped).strip()
            if sub_text:
                # 清理Markdown加粗标记，但保留关键词
                current_module["sub_points"].append(sub_text)
            continue

        # 普通段落（追加到当前模块描述）
        if current_module and line_stripped:
            if current_module["description"]:
                current_module["description"] += " " + line_stripped
            else:
                current_module["description"] = line_stripped

    if current_module:
        knowledge_points.append(current_module)

    return knowledge_points


def split_answer_block(raw_q: str) -> Dict[str, str]:
    """
    从题目文本中分离题干和答案解析
    标记：@@ANSWER_START@@ ... @@ANSWER_END@@
    返回: {"body": 题干, "answer_raw": 答案块原文}
    """
    answer_pattern = r'@@ANSWER_START@@\s*(.*?)\s*@@ANSWER_END@@'
    m = re.search(answer_pattern, raw_q, re.DOTALL)
    if m:
        body       = raw_q[:m.start()].strip()
        answer_raw = m.group(1).strip()
    else:
        # 没有标记：尝试以 **答案：** 分割
        m2 = re.search(r'\*\*答案[：:]\*\*', raw_q)
        body       = raw_q[:m2.start()].strip() if m2 else raw_q.strip()
        answer_raw = raw_q[m2.start():].strip() if m2 else ""

    return {"body": body, "answer_raw": answer_raw}


def parse_answer_explanation(answer_raw: str) -> Dict[str, str]:
    """从答案块中提取答案值和解析文本"""
    answer = explanation = ""

    ans_m = re.search(r'\*\*答案[：:]\*\*\s*([^\n*]+)', answer_raw)
    if ans_m:
        answer = ans_m.group(1).strip()

    exp_m = re.search(r'\*\*解析[：:]\*\*\s*(.+?)(?=\*\*|$)', answer_raw, re.DOTALL)
    if exp_m:
        explanation = exp_m.group(1).strip()

    return {"answer": answer, "explanation": explanation}


def parse_options(question_body: str) -> Dict[str, str]:
    """提取选项 A B C D"""
    options: Dict[str, str] = {}
    pattern = r'^([ABCD])[.．、]\s*(.+)'
    for line in question_body.splitlines():
        m = re.match(pattern, line.strip())
        if m:
            options[m.group(1)] = m.group(2).strip()
    return options


def clean_question_body(body: str) -> str:
    """清理题干（去掉选项行，保留题干文字）"""
    lines = []
    for line in body.splitlines():
        stripped = line.strip()
        if re.match(r'^[ABCD][.．、]', stripped):
            break  # 遇到选项行就停止
        if stripped:
            lines.append(stripped)
    return " ".join(lines)


def parse_question_block(raw: str, q_type: str, q_index: int) -> Dict[str, Any]:
    """解析单道题目"""
    parts = split_answer_block(raw)
    ae    = parse_answer_explanation(parts["answer_raw"])
    body  = parts["body"]

    base = {
        "id":          q_index,
        "type":        q_type,
        "question":    "",
        "answer":      ae["answer"],
        "explanation": ae["explanation"],
    }

    if q_type in ("single_choice", "multiple_choice"):
        options = parse_options(body)
        base["question"] = clean_question_body(body)
        base["options"]  = options
        # 规范化答案格式
        base["answer"] = re.sub(r'[^ABCD]', '', ae["answer"].upper())

    elif q_type == "true_false":
        # 判断题只有题干
        base["question"] = re.sub(r'\*\*第\d+题\*\*\s*', '', body).strip()
        base["answer"] = "对" if "对" in ae["answer"] else "错"

    elif q_type == "short_answer":
        base["question"] = re.sub(r'\*\*第\d+题\*\*\s*', '', body).strip()
        # 提取分点答案
        points = re.findall(r'^\d+[.．、]\s*(.+)', parts["answer_raw"], re.MULTILINE)
        base["answer_points"] = points if points else [ae["answer"]]
        base["answer"] = ae["answer"]

    else:
        base["question"] = body

    return base


def parse_question_section(section_text: str, q_type: str) -> List[Dict]:
    """解析一种题型的所有题目"""
    # 按 **第N题** 分割
    parts = re.split(r'(?=\*\*第\d+题\*\*)', section_text)
    questions: List[Dict] = []

    for i, part in enumerate(parts, start=1):
        part = part.strip()
        if not part or not re.match(r'\*\*第\d+题\*\*', part):
            continue
        try:
            q = parse_question_block(part, q_type, i)
            if q["question"]:
                questions.append(q)
        except Exception as e:
            log.warning(f"    解析第{i}题失败: {e}")

    return questions


def parse_questions(chapter_text: str) -> Dict[str, List[Dict]]:
    """解析题库部分（## 二、本章刷题题库）"""
    # 提取题库区块
    m = re.search(
        r'##\s*二[、.．]?\s*本章刷题题库(.*?)(?=##\s*[一三四五六七八九十]|\Z)',
        chapter_text, re.DOTALL
    )
    if not m:
        return {"single_choice": [], "multiple_choice": [], "true_false": [], "short_answer": []}

    qtext = m.group(1)

    # 提取各题型区块
    def extract_section(label: str) -> str:
        # 匹配 ### 【XXX题】 到下一个 --- 或 ### 或文末
        pat = rf'###\s*【{label}】.*?(?=---\n###|###\s*【|\Z)'
        sm = re.search(pat, qtext, re.DOTALL)
        return sm.group() if sm else ""

    sc_text  = extract_section("单选题")
    mc_text  = extract_section("多选题")
    tf_text  = extract_section("判断题")
    sa_text  = extract_section("简答题")

    return {
        "single_choice":   parse_question_section(sc_text,  "single_choice"),
        "multiple_choice": parse_question_section(mc_text, "multiple_choice"),
        "true_false":      parse_question_section(tf_text,  "true_false"),
        "short_answer":    parse_question_section(sa_text,  "short_answer"),
    }


def parse_chapter(chapter_text: str, chapter_id: int) -> Dict[str, Any]:
    """解析单个章节，返回完整结构"""
    title = parse_chapter_title(chapter_text)
    log.info(f"  解析: {title}")

    knowledge_points = parse_knowledge_points(chapter_text)
    questions        = parse_questions(chapter_text)

    q_counts = {k: len(v) for k, v in questions.items()}
    log.info(f"    知识点模块: {len(knowledge_points)}，题目: {q_counts}")

    return {
        "chapter_id":       chapter_id,
        "chapter_title":    title,
        "knowledge_points": knowledge_points,
        "questions":        questions,
        "stats": {
            "knowledge_modules": len(knowledge_points),
            "single_choice":     len(questions["single_choice"]),
            "multiple_choice":   len(questions["multiple_choice"]),
            "true_false":        len(questions["true_false"]),
            "short_answer":      len(questions["short_answer"]),
            "total_questions":   sum(q_counts.values()),
        },
    }


# ╔══════════════════════════════════════════════════════╗
# ║                  JSON 输出模块                     ║
# ╚══════════════════════════════════════════════════════╝

def save_json(data: Any, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    size_kb = path.stat().st_size / 1024
    log.info(f"  💾 {path.name}（{size_kb:.1f} KB）")


def generate_all_outputs(chapters: List[Dict]):
    """生成所有输出JSON文件"""
    JSON_DIR.mkdir(parents=True, exist_ok=True)

    # 1. 每章独立文件
    log.info("\n生成章节独立JSON...")
    for ch in chapters:
        cid = ch["chapter_id"]
        save_json(ch, JSON_DIR / f"chapter_{cid:03d}.json")

    # 2. 全书汇总（含所有章节）
    log.info("\n生成全书汇总...")
    summary = {
        **COURSE_METADATA,
        "total_chapters":   len(chapters),
        "total_questions":  sum(c["stats"]["total_questions"] for c in chapters),
        "total_kp_modules": sum(c["stats"]["knowledge_modules"] for c in chapters),
        "chapters":         chapters,
    }
    save_json(summary, JSON_DIR / "chapters.json")

    # 3. 仅知识点（学习/阅读模块）
    log.info("\n生成知识点专用JSON...")
    kp_data = [
        {
            "chapter_id":    ch["chapter_id"],
            "chapter_title": ch["chapter_title"],
            "knowledge_points": ch["knowledge_points"],
        }
        for ch in chapters
    ]
    save_json(kp_data, JSON_DIR / "knowledge_only.json")

    # 4. 仅题库（刷题模块，答案题干分离）
    log.info("\n生成题库专用JSON...")
    qs_data = []
    global_q_id = 1
    for ch in chapters:
        for q_type, qs in ch["questions"].items():
            for q in qs:
                entry = {
                    "gid":           global_q_id,
                    "chapter_id":    ch["chapter_id"],
                    "chapter_title": ch["chapter_title"],
                    **q,
                }
                qs_data.append(entry)
                global_q_id += 1
    save_json(qs_data, JSON_DIR / "questions_only.json")

    # 5. 按题型分类题库
    log.info("\n生成分题型JSON...")
    by_type: Dict[str, List] = {
        "single_choice": [], "multiple_choice": [],
        "true_false": [],    "short_answer": [],
    }
    gid = 1
    for ch in chapters:
        for q_type, qs in ch["questions"].items():
            for q in qs:
                by_type[q_type].append({
                    "gid": gid,
                    "chapter_id": ch["chapter_id"],
                    "chapter_title": ch["chapter_title"],
                    **q
                })
                gid += 1
    save_json(by_type, JSON_DIR / "questions_by_type.json")

    # 6. API-ready（题干和答案分离，适合做题隐藏答案）
    log.info("\n生成APP刷题格式JSON（题干/答案分离）...")
    quiz_items = []
    for ch in chapters:
        for q_type, qs in ch["questions"].items():
            for q in qs:
                # 题面（不含答案）
                question_face = {
                    "id":            q.get("id"),
                    "chapter_id":    ch["chapter_id"],
                    "chapter_title": ch["chapter_title"],
                    "type":          q_type,
                    "question":      q.get("question", ""),
                    "options":       q.get("options", {}),  # 判断/简答为空
                }
                # 答案（分离存储，APP点击"查看答案"时加载）
                answer_face = {
                    "id":          q.get("id"),
                    "chapter_id":  ch["chapter_id"],
                    "answer":      q.get("answer", ""),
                    "explanation": q.get("explanation", ""),
                }
                if q_type == "short_answer":
                    answer_face["answer_points"] = q.get("answer_points", [])

                quiz_items.append({
                    "question": question_face,
                    "answer":   answer_face,
                })
    save_json(quiz_items, JSON_DIR / "quiz_app_format.json")

    # ── 输出统计 ───────────────────────────────────
    log.info(f"\n{'='*50}")
    log.info(f"  ✅ JSON输出完成！输出目录: {JSON_DIR.resolve()}")
    log.info(f"  📊 统计：")
    log.info(f"     章节数:    {len(chapters)}")
    log.info(f"     总题目数:  {summary['total_questions']}")
    log.info(f"     知识模块:  {summary['total_kp_modules']}")
    log.info(f"  📂 文件清单：")
    for f in sorted(JSON_DIR.glob("*.json")):
        kb = f.stat().st_size / 1024
        log.info(f"     {f.name:<35} {kb:>8.1f} KB")
    log.info(f"{'='*50}")


# ╔══════════════════════════════════════════════════════╗
# ║                     主程序                        ║
# ╚══════════════════════════════════════════════════════╝

def main():
    parser = argparse.ArgumentParser(
        description="教辅内容JSON解析器",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--input", help="输入Markdown文件路径（final_output.md）")
    group.add_argument("--dir",   help="输入章节目录（03_chapters/）")
    parser.add_argument("--out",  default="output/json", help="JSON输出目录（默认 output/json）")
    parser.add_argument("--course-id", help="稳定且唯一的课程 ID")
    parser.add_argument("--course-title", help="课程显示名称")
    parser.add_argument("--course-subtitle", help="课程简介")
    parser.add_argument("--course-subject", help="课程分类")
    parser.add_argument(
        "--course-accent",
        choices=["indigo", "cyan", "coral", "violet", "mint"],
        help="课程主题色",
    )
    args = parser.parse_args()

    global JSON_DIR, COURSE_METADATA
    JSON_DIR = Path(args.out)
    COURSE_METADATA = {
        key: value
        for key, value in {
            "course_id": args.course_id,
            "course_title": args.course_title,
            "course_subtitle": args.course_subtitle,
            "course_subject": args.course_subject,
            "course_accent": args.course_accent,
        }.items()
        if value
    }

    # 读取输入
    if args.input:
        input_path = Path(args.input)
        if not input_path.exists():
            log.error(f"❌ 文件不存在: {input_path}")
            sys.exit(1)
        text = input_path.read_text(encoding="utf-8")
        chapter_texts = split_chapters(text)

    elif args.dir:
        chapter_dir = Path(args.dir)
        md_files = sorted(chapter_dir.glob("*.md"))
        if not md_files:
            log.error(f"❌ 目录中没有.md文件: {chapter_dir}")
            sys.exit(1)
        chapter_texts = []
        for f in md_files:
            content = f.read_text(encoding="utf-8")
            # 每个文件可能包含多个章节块
            blocks = split_chapters(content)
            if blocks:
                chapter_texts.extend(blocks)
            else:
                chapter_texts.append(content)
        log.info(f"  从 {len(md_files)} 个文件读取到 {len(chapter_texts)} 个章节")

    else:
        sys.exit(1)

    if not chapter_texts:
        log.error("❌ 未找到任何章节内容")
        sys.exit(1)

    # 解析所有章节
    log.info(f"\n📚 开始解析 {len(chapter_texts)} 个章节...")
    chapters = []
    for i, ch_text in enumerate(chapter_texts, start=1):
        ch = parse_chapter(ch_text, i)
        chapters.append(ch)

    # 生成所有JSON输出
    generate_all_outputs(chapters)


if __name__ == "__main__":
    main()
