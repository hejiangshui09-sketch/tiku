import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var prefs: AppPreferences
    @State private var showingResetConfirmation = false
    @State private var backupDocument: LearningBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("外观模式", selection: $prefs.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("应用主题色")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 8), spacing: 12) {
                            ForEach(AppTint.allCases) { tint in
                                Button {
                                    Haptics.selection()
                                    prefs.tint = tint
                                } label: {
                                    Circle()
                                        .fill(tint.color)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if prefs.tint == tint {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .overlay {
                                            Circle().stroke(
                                                prefs.tint == tint ? tint.color.opacity(0.4) : .clear,
                                                lineWidth: 3
                                            )
                                            .padding(-4)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tint.title)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("触觉反馈", isOn: $prefs.hapticsEnabled)
                } header: {
                    Text("个性化外观")
                } footer: {
                    Text("主题色会应用到导航、首页横幅和强调元素。")
                }

                Section {
                    NavigationLink {
                        ReadingPreferencePage()
                    } label: {
                        HStack {
                            Label("阅读偏好", systemImage: "textformat.size")
                            Spacer()
                            Text("\(prefs.readingTheme.title) · \(prefs.readingFontDesign.title) · \(prefs.readingFontScale.formatted(.percent.precision(.fractionLength(0))))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("阅读")
                } footer: {
                    Text("阅读主题、正文字体、字号与行距，与章节阅读页内的设置保持同步。")
                }

                Section {
                    Stepper(value: $prefs.dailyGoalMinutes, in: 10...240, step: 10) {
                        HStack {
                            Label("每日学习目标", systemImage: "target")
                            Spacer()
                            Text("\(prefs.dailyGoalMinutes) 分钟")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("学习目标")
                } footer: {
                    Text("学习首页的目标环会按此目标显示今日完成度。")
                }

                Section {
                    HStack(spacing: 14) {
                        Image(systemName: model.network.isConnected ? "wifi" : "wifi.slash")
                            .font(.title2)
                            .foregroundStyle(model.network.isConnected ? .green : .orange)
                            .frame(width: 44, height: 44)
                            .background((model.network.isConnected ? Color.green : Color.orange).opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.network.isConnected ? "网络已连接" : "当前离线")
                                .font(.headline)
                            Text(model.network.isConnected ? model.network.connectionName : "本地课程仍可正常学习")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                } header: {
                    Text("网络状态")
                }

                Section {
                    TextField("https://example.com/catalog.json", text: $model.catalogURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button {
                        Task { await model.refreshRemoteCatalog() }
                    } label: {
                        Label("加载在线课程目录", systemImage: "network")
                    }
                    .disabled(!model.network.isConnected || model.catalogURLString.isEmpty)
                } header: {
                    Text("在线课程目录")
                } footer: {
                    Text("课程目录可以列出多门课程，用户可在在线课程库中按需安装。")
                }

                Section {
                    TextField("https://example.com/chapters.json", text: $model.remoteURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Button {
                        Task { await model.syncRemoteCourse() }
                    } label: {
                        Label("立即同步在线课程", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!model.network.isConnected || model.remoteURLString.isEmpty)
                } header: {
                    Text("在线课程源")
                } footer: {
                    Text("地址应直接返回与当前解析器 chapters.json 相同结构的 JSON。后续可将此处替换为带鉴权的课程 API。")
                }

                Section {
                    LabeledContent("数据格式", value: "chapters.json")
                    LabeledContent("最低系统", value: "iPadOS 17")
                    LabeledContent("设备布局", value: "iPad 自适应三栏")
                    LabeledContent("离线能力", value: "已启用")
                    LabeledContent("课程缓存", value: "独立文件存储")
                    LabeledContent("复习计划", value: "自动间隔调度")
                    LabeledContent("拓展资源", value: "应用内查看")
                } header: {
                    Text("应用能力")
                }

                Section {
                    Toggle(
                        "每日复习提醒",
                        isOn: Binding(
                            get: { model.reviewRemindersEnabled },
                            set: { enabled in
                                Task { await model.setReviewReminders(enabled: enabled) }
                            }
                        )
                    )
                } header: {
                    Text("学习提醒")
                } footer: {
                    Text("开启后每天 20:00 提醒完成到期复习。")
                }

                Section {
                    Text("学程使用本地持久化保存学习进度、答题结果和收藏。远程同步只读取你配置的课程 JSON 地址。")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("数据与隐私")
                }

                Section {
                    LabeledContent("已下载资源", value: "\(model.offlineResourcePaths.count) 个")
                    Button("清理离线资源", role: .destructive) {
                        Task { await model.clearDownloadedResources() }
                    }
                    .disabled(model.offlineResourcePaths.isEmpty)
                } header: {
                    Text("离线资源")
                } footer: {
                    Text("课程知识与题目始终可离线使用；视频、音频、图片和讲义可按需下载。")
                }

                Section {
                    Button {
                        Task {
                            if let data = await model.makeBackupData() {
                                backupDocument = LearningBackupDocument(data: data)
                                isExportingBackup = true
                            }
                        }
                    } label: {
                        Label("导出学习记录", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isImportingBackup = true
                    } label: {
                        Label("恢复学习记录", systemImage: "square.and.arrow.down")
                    }

                    Button("重置全部学习记录", role: .destructive) {
                        showingResetConfirmation = true
                    }
                } header: {
                    Text("数据管理")
                } footer: {
                    Text("只清除进度、答题记录、复习计划、收藏和笔记，不会删除课程内容。")
                }
            }
            .navigationTitle("设置")
            .confirmationDialog(
                "确定重置全部学习记录？",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("重置学习记录", role: .destructive) {
                    model.clearLearningData()
                }
                Button("取消", role: .cancel) {}
            }
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: "ScholarPad-learning-backup"
            ) { result in
                if case .failure(let error) = result {
                    if (error as? CocoaError)?.code != .userCancelled {
                        model.notice = "无法导出学习备份：\(error.localizedDescription)"
                    }
                }
                backupDocument = nil
            }
            .fileImporter(
                isPresented: $isImportingBackup,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                Task { await model.restoreBackup(from: url) }
            }
        }
    }
}

/// 设置页内的阅读偏好页面，复用阅读器的设置面板。
private struct ReadingPreferencePage: View {
    @EnvironmentObject private var prefs: AppPreferences

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ReadingOptionsPanel(accent: prefs.tint.color)
                    .scholarCard(padding: 6)

                // 实时预览
                VStack(alignment: .leading, spacing: 12) {
                    Text("预览")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("细胞的结构与功能")
                            .font(.system(size: 22 * prefs.readingFontScale, weight: .bold, design: prefs.readingFontDesign.design))
                            .foregroundStyle(prefs.readingTheme.textColor)
                        Text("细胞是生物体结构和功能的基本单位。真核细胞具有由核膜包被的细胞核，遗传物质主要存在于细胞核中。")
                            .font(.system(size: 17 * prefs.readingFontScale, design: prefs.readingFontDesign.design))
                            .foregroundStyle(prefs.readingTheme.secondaryTextColor)
                            .lineSpacing(prefs.readingLineSpacing)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(prefs.readingTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .background(prefs.readingTheme.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.primary.opacity(0.07), lineWidth: 1)
                    }
                }
                .frame(maxWidth: 400)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(ScholarTheme.page)
        .navigationTitle("阅读偏好")
        .navigationBarTitleDisplayMode(.inline)
    }
}
