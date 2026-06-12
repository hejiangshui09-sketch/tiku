# 知识学习库

面向 iPad 的原生知识整理与学习应用源码。项目使用 SwiftUI 和 iPadOS 17，直接兼容现有解析器生成的 `chapters.json`。

## 已实现

- iPad 自适应侧边栏与大屏三栏导航
- 全局个性化：深浅外观模式、8 种应用主题色、触觉反馈开关（设置 → 个性化外观）
- 阅读器 2.0：默认/纸张/护眼/夜间四种阅读主题，系统/衬线/圆体三种正文字体，字号与行距滑块，全部持久化并在设置中实时预览
- 章节阅读：顶部阅读进度条、上一节/下一节导航、目录完成度统计、专注模式
- 课程目录：封面渐变课程卡片、搜索、按最近学习/名称/完成度/题量排序、长按修改课程主题色
- 可自定义命名的书柜分组，章节以抽屉形式分别收纳单元知识与题库
- 网盘分享页和视频、音频、文档直链资源库
- 导入预览确认页：导入前展示课程名、章节/知识点/题目数量、章节预览、新课程或更新提示、逐个勾选与改色，解析失败附原因
- 课程详情：大封面头图、继续学习按钮、章节完成标记与"上次学到这里"标签
- 练习 2.0：顺序/乱序/背题三种模式、答题卡跳题、练习计时、答对答错触觉与动效、结果页错题重练
- 学习首页：动态欢迎语、每日学习目标环（目标可在设置调整）、近 4 周学习热力图
- 单选、多选、判断、简答练习，含答案解析和简答自评
- 知识点掌握状态、答题记录、收藏、学习时长和连续学习统计
- 自动间隔复习、错题强化队列和知识点学习笔记
- 可选每日复习本地通知提醒
- 学习进度、复习计划、收藏和笔记的 JSON 备份与恢复
- App Store 隐私清单：不跟踪、不收集用户数据，并声明应用内 UserDefaults 用途
- 全局搜索、近 7 天学习图表、课程完成度
- 本地 JSON 文件导入、远程 HTTPS JSON 同步、独立文件缓存和离线学习
- 在线多课程目录、按需安装、离线目录缓存和课程更新
- 应用内视频、音频、图片、讲义和网页资源查看器
- 视频、音频、图片和讲义按需下载与离线播放
- `UserDefaults + Codable` 本地持久化框架
- 示例课程数据与解码单元测试

## 在 Xcode 中运行

工程使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 描述，避免提交容易损坏的手工 `pbxproj`。

```bash
brew install xcodegen
cd ScholarPad
xcodegen generate
open ScholarPad.xcodeproj
```

选择任意 iPad 模拟器，或连接 2018 款 12.9 英寸 iPad Pro 后运行。应用目标设备已限制为 iPad，最低系统为 iPadOS 17。

也可以在 Xcode 中创建一个新的 iPad App，再将 `ScholarPad/` 下的源码和 `Resources/chapters.json` 拖入工程。

项目附带 `.github/workflows/ios.yml`。将 `ScholarPad` 目录作为仓库根目录推送到 GitHub 后，会在 macOS runner 上自动生成 Xcode 工程，并编译应用与单元测试目标。

测试通过后，工作流还会构建设备版应用并上传 `ScholarPad-unsigned-<commit SHA>` Artifact，其中包含 `ScholarPad-unsigned.ipa`。该 IPA 未签名，不能直接安装到普通 iPad；使用前需要通过你自己的证书或侧载工具签名。

应用本身没有内容到期或功能到期逻辑；但 iPad 上的安装有效期由签名证书和安装方式决定，无法通过应用代码设置为永久。

## 交付审计

在任意系统检查源码、课程数据、应用图标和项目完整性：

```bash
python tools/audit_project.py
```

在安装了 Xcode 与 XcodeGen 的 macOS 上执行真实 iOS 模拟器编译：

```bash
python tools/audit_project.py --build
```

生成一个不包含缓存和构建产物、可直接传到 macOS 的源码压缩包：

```bash
python tools/package_source.py
```

## 导入自己的课程

1. 使用附带的兼容解析器生成 `output/json/chapters.json`。
2. 在应用的“我的书柜”页面点击“导入书籍”。
3. 选择一个或多个生成的 `chapters.json`。

解析 Markdown 时可直接写入课程元数据：

```bash
python tools/parse_to_json.py \
  --input output/final_output.md \
  --out output/json \
  --course-id biology-2026 \
  --course-title 生物学基础 \
  --course-subject 生物 \
  --course-accent mint
```

不提供新增参数时，命令与原始解析器完全兼容。

导入前可用附带脚本检查字段和数量是否一致：

```bash
python tools/validate_course.py output/json/chapters.json
```

也可以为解析器生成的文件一次性写入稳定课程 ID、名称与主题：

```bash
python tools/set_course_metadata.py output/json/chapters.json \
  --id biology-2026 \
  --title 生物学基础 \
  --subject 生物 \
  --accent mint
```

应用的数据模型严格对应以下根结构：

```json
{
  "course_id": "stable-course-id",
  "course_title": "课程名称",
  "total_chapters": 1,
  "total_questions": 4,
  "total_kp_modules": 2,
  "chapters": []
}
```

建议为每门课程提供唯一且长期不变的 `course_id`，以便重复导入时更新原课程，而不是创建重复课程。

每章支持 `knowledge_points`、`questions.single_choice`、`multiple_choice`、`true_false`、`short_answer` 和 `stats`，与你当前解析器的输出一致。

完整字段说明见 [Docs/COURSE_FORMAT.md](Docs/COURSE_FORMAT.md)。

源码模块、网络层和后续扩展说明见 [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md)。

知识点可选添加拓展资源，不添加时完全兼容原始解析结果：

```json
{
  "title": "知识点",
  "description": "说明",
  "sub_points": [],
  "resources": [
    {
      "id": "video-001",
      "title": "拓展讲解",
      "kind": "video",
      "url": "https://example.com/video",
      "detail": "12 分钟"
    }
  ]
}
```

## 接入在线课程

“设置”中可填写直接返回 `chapters.json` 的 HTTPS 地址。当前网络层已经包含超时、状态码校验、离线检测和错误提示。生产环境可在 `Services/ContentRepository.swift` 中继续加入登录鉴权、分页、版本校验和下载缓存。

## 推荐后续资源组织

课程 JSON 建议继续保持纯文本内容；图片、视频和附件可新增稳定 URL 字段，通过课程 ID、章节 ID 和知识点序号关联。这样无需破坏当前数据，也便于后续切换到正式课程 API。
