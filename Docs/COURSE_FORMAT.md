# 课程 JSON 格式

ScholarPad 直接读取现有解析器生成的 `chapters.json`。根级统计字段与章节 `stats` 可以省略，应用会根据实际内容自动计算。

应用也支持直接导入解析器生成的单章文件，例如 `chapter_001.json`。单章文件会作为一门独立课程导入，并使用 `chapter_title` 作为课程名称。需要一次导入多章为同一门课程时，仍建议使用汇总后的 `chapters.json`。

## 根结构

```json
{
  "course_id": "stable-course-id",
  "course_title": "课程名称",
  "course_subtitle": "课程简介",
  "course_subject": "课程分类",
  "course_accent": "indigo",
  "total_chapters": 1,
  "total_questions": 4,
  "total_kp_modules": 2,
  "chapters": []
}
```

课程元数据均可省略。强烈建议为每门课程提供长期不变且唯一的 `course_id`，这样从不同位置重新导入时仍会更新同一门课程。`course_accent` 支持 `indigo`、`cyan`、`coral`、`violet` 和 `mint`。

## 章节

```json
{
  "chapter_id": 1,
  "chapter_title": "第一章",
  "knowledge_points": [],
  "questions": {},
  "stats": {}
}
```

`chapter_id` 应在同一门课程内保持唯一。`chapter_title`、`knowledge_points`、`questions` 和 `stats` 缺失时应用会使用安全默认值，但建议完整提供。

## 知识点

```json
{
  "title": "知识点标题",
  "description": "支持 Markdown 风格的正文说明",
  "sub_points": ["子知识点一", "子知识点二"],
  "resources": [
    {
      "id": "video-001",
      "title": "拓展讲解",
      "kind": "video",
      "url": "https://example.com/video.mp4",
      "detail": "12 分钟"
    }
  ]
}
```

`resources` 可省略。支持的 `kind`：

- `video`：应用内视频播放器
- `audio`：应用内音频播放器
- `image`：应用内图片查看器
- `document`：应用内讲义或 PDF 浏览
- `link`：应用内网页浏览

资源地址必须使用 HTTPS，以满足网络安全和离线下载要求。

## 题库

```json
{
  "questions": {
    "single_choice": [],
    "multiple_choice": [],
    "true_false": [],
    "short_answer": []
  }
}
```

每个题型数组都可以省略。选择题示例：

```json
{
  "id": 1,
  "type": "single_choice",
  "question": "题干",
  "options": {
    "A": "选项 A",
    "B": "选项 B"
  },
  "answer": "A",
  "explanation": "答案解析"
}
```

多选题答案使用连续字母，例如 `ACD`。判断题答案推荐使用 `对` 或 `错`。简答题可额外提供：

```json
{
  "answer_points": ["要点一", "要点二"]
}
```

## 导入前验证

```bash
python tools/validate_course.py path/to/chapters.json
```

验证器会检查章节 ID、题型、题目字段、资源类型以及各统计数量是否一致。

可使用附带脚本为现有解析结果写入课程元数据：

```bash
python tools/set_course_metadata.py path/to/chapters.json \
  --id stable-course-id \
  --title 课程名称 \
  --subject 课程分类 \
  --accent indigo
```

也可以在解析阶段直接写入：

```bash
python tools/parse_to_json.py \
  --input output/final_output.md \
  --out output/json \
  --course-id stable-course-id \
  --course-title 课程名称
```

## 在线课程目录

应用设置页可配置一个 HTTPS 在线课程目录。目录格式参考 [`catalog.example.json`](catalog.example.json)：

```json
{
  "version": 1,
  "updated_at": "2026-06-11T12:00:00Z",
  "courses": [
    {
      "id": "stable-course-id",
      "title": "课程名称",
      "course_url": "https://example.com/chapters.json"
    }
  ]
}
```

目录和课程内容会缓存到应用支持目录。课程安装完成后可以离线学习；在线地址必须使用 HTTPS。
