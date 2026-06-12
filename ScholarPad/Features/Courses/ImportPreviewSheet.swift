import SwiftUI

/// 导入前的预览确认页：展示每个文件解析出的课程信息、
/// 是否会更新已有课程、解析失败原因，并允许逐个勾选与改主题色。
struct ImportPreviewSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var previews: [CourseImportPreview]
    @State private var selectedIDs: Set<String>
    let onFinish: () -> Void

    init(previews: [CourseImportPreview], onFinish: @escaping () -> Void) {
        _previews = State(initialValue: previews)
        _selectedIDs = State(initialValue: Set(previews.filter { $0.course != nil }.map(\.id)))
        self.onFinish = onFinish
    }

    private var importableCount: Int {
        previews.filter { $0.course != nil && selectedIDs.contains($0.id) }.count
    }

    private var failedCount: Int {
        previews.filter { $0.course == nil }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryHeader

                    ForEach($previews) { $preview in
                        if let course = preview.course {
                            ImportCourseRow(
                                preview: $preview,
                                course: course,
                                isSelected: selectedIDs.contains(preview.id),
                                toggle: { toggle(preview.id) }
                            )
                        } else {
                            ImportErrorRow(preview: preview)
                        }
                    }
                }
                .padding(24)
            }
            .background(ScholarTheme.page)
            .navigationTitle("确认导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                        onFinish()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let selected = previews.compactMap { preview -> Course? in
                            guard selectedIDs.contains(preview.id) else { return nil }
                            return preview.course
                        }
                        Task {
                            await model.confirmImport(selected)
                            dismiss()
                            onFinish()
                        }
                    } label: {
                        Text(importableCount > 0 ? "导入 \(importableCount) 门课程" : "导入")
                            .fontWeight(.semibold)
                    }
                    .disabled(importableCount == 0)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func toggle(_ id: String) {
        Haptics.selection()
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("已解析 \(previews.count) 个文件")
                    .font(.headline)
                Text(failedCount > 0
                     ? "\(previews.count - failedCount) 个可导入 · \(failedCount) 个解析失败"
                     : "全部解析成功，确认课程信息后导入")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .scholarCard(padding: 16)
    }
}

// MARK: - 可导入课程行

private struct ImportCourseRow: View {
    @Binding var preview: CourseImportPreview
    let course: Course
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Button(action: toggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(course.accent.coverGradient)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: course.accent.coverSymbol)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(course.title)
                            .font(.headline)
                            .lineLimit(1)
                        if preview.isUpdate {
                            InfoChip(text: "将更新已有课程", symbol: "arrow.triangle.2.circlepath", color: .orange)
                        } else {
                            InfoChip(text: "新课程", symbol: "sparkles", color: .green)
                        }
                    }
                    Text(preview.fileName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        InfoChip(text: "\(course.payload.totalChapters) 章", symbol: "list.number", color: course.accent.color)
                        InfoChip(text: "\(course.totalKnowledgeModules) 知识点", symbol: "lightbulb", color: course.accent.color)
                        InfoChip(text: "\(course.totalQuestions) 题", symbol: "checkmark.circle", color: course.accent.color)
                    }
                }
                Spacer()

                Menu {
                    ForEach(CourseAccent.allCases, id: \.self) { accent in
                        Button {
                            preview.course?.accent = accent
                        } label: {
                            Label(accent.title, systemImage: course.accent == accent ? "checkmark.circle.fill" : "circle.fill")
                        }
                    }
                } label: {
                    Circle()
                        .fill(course.accent.color)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(.primary.opacity(0.12), lineWidth: 1))
                        .overlay {
                            Image(systemName: "paintbrush.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.white)
                        }
                }
            }

            // 章节预览
            if !course.payload.chapters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(course.payload.chapters.prefix(3)) { chapter in
                        HStack(spacing: 8) {
                            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                .font(.caption2)
                                .foregroundStyle(course.accent.color)
                            Text(chapter.chapterTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(chapter.stats.totalQuestions) 题")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                    if course.payload.chapters.count > 3 {
                        Text("… 还有 \(course.payload.chapters.count - 3) 个章节")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background(course.accent.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .scholarCard(padding: 16)
        .opacity(isSelected ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - 解析失败行

private struct ImportErrorRow: View {
    let preview: CourseImportPreview

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 52, height: 52)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(preview.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Text(preview.errorMessage ?? "无法解析该文件")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("可先运行 tools/validate_course.py 检查文件格式")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .scholarCard(padding: 16)
    }
}
