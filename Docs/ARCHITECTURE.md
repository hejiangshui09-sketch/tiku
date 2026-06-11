# ScholarPad 架构与扩展点

## 技术基线

- SwiftUI
- iPadOS 17+
- 仅 iPad 目标设备
- Swift 5.9，开启完整并发检查
- `NavigationSplitView` 大屏导航
- `Codable` 课程数据契约

2018 款 12.9 英寸 iPad Pro 支持 iPadOS 17。横屏时章节阅读显示目录与正文双栏；空间较窄或进入专注模式时自动收起目录。

## 主要数据流

```text
本地 chapters.json ─┐
文件导入             ├─ ContentRepository ─ CoursePayload ─ AppModel ─ SwiftUI
在线课程目录/课程 ───┘                          │
                                               ├─ 进度、复习、笔记、收藏
                                               └─ 离线资源下载与播放
```

## 目录结构

- `App/`：应用入口、主导航和侧边栏
- `DesignSystem/`：卡片、指标、进度环和统一视觉规范
- `Models/`：课程、题库、资源、进度、复习和笔记模型
- `Services/ContentRepository.swift`：课程导入、HTTPS 获取和文件缓存
- `Services/CourseValidator.swift`：章节、题目和资源 ID 语义校验
- `Services/AppModel.swift`：应用状态与学习业务逻辑
- `Services/ReviewScheduler.swift`：间隔复习算法
- `Services/ResourceDownloadService.swift`：拓展资源离线下载
- `Services/ReviewReminderService.swift`：本地复习提醒
- `Services/LearningBackupService.swift`：学习记录 JSON 备份与恢复
- `Features/`：首页、课程、阅读、练习、搜索、笔记、统计和设置

## 本地存储

- 内置课程：应用资源中的 `chapters.json`
- 导入和在线课程：`Application Support/ScholarPad/Courses`
- 在线目录缓存：`Application Support/ScholarPad/catalog.json`
- 下载资源：`Application Support/ScholarPad/Resources`
- 轻量学习状态：`UserDefaults + Codable`
- 用户导出备份：课程无关的进度、复习、收藏与笔记 JSON

课程内容与大型资源不会存入 `UserDefaults`。

## 隐私

应用不包含第三方分析 SDK，不进行跨应用跟踪，也不上传学习记录。`PrivacyInfo.xcprivacy` 声明：

- `NSPrivacyTracking = false`
- 不收集用户数据
- 使用 `CA92.1` 原因访问仅供本应用保存状态的 `UserDefaults`

## 在线课程协议

应用支持两类 HTTPS 地址：

1. 直接课程地址：返回一份 `chapters.json`。
2. 在线课程目录：返回多门课程描述和各自的 `course_url`。

目录格式见 [`catalog.example.json`](catalog.example.json)。生产服务可在 `ContentRepository.fetchJSON` 中加入：

- Bearer Token 或签名请求
- ETag / If-None-Match
- 课程版本和增量更新
- 组织、用户与权限控制
- 埋点和服务端学习进度同步

## 后续资源扩展

知识点的 `resources` 已支持视频、音频、图片、讲义和网页。新增资源类型时：

1. 在 `LearningResourceKind` 添加类型。
2. 在 `ResourceViewerView` 添加展示方式。
3. 在 `ResourceDownloadService.fileExtension` 添加默认扩展名。
4. 在 `tools/validate_course.py` 添加允许值。

## 构建与质量门槛

- `python tools/audit_project.py`：跨平台交付审计
- `python tools/audit_project.py --build`：macOS 上真实模拟器编译
- `.github/workflows/ios.yml`：自动生成 Xcode 工程并运行单元测试
