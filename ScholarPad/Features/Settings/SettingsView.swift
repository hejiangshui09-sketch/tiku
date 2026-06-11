import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingResetConfirmation = false
    @State private var backupDocument: LearningBackupDocument?
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false

    var body: some View {
        NavigationStack {
            Form {
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
