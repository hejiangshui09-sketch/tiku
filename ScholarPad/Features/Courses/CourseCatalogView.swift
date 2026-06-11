import SwiftUI
import UniformTypeIdentifiers

struct CourseCatalogView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isImporting = false
    @State private var coursePendingDeletion: Course?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    catalogHero
                    SectionHeading(
                        title: "全部课程",
                        subtitle: "\(model.courses.count) 门课程已就绪，支持离线学习"
                    )

                    if model.courses.isEmpty {
                        EmptyState(symbol: "books.vertical", title: "还没有课程", detail: "导入解析器生成的 chapters.json 开始学习")
                            .frame(height: 360)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                            ForEach(model.courses) { course in
                                NavigationLink {
                                    CourseDetailView(course: course)
                                } label: {
                                    CourseSummaryCard(course: course)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if !course.source.isBundled {
                                        Button(role: .destructive) {
                                            coursePendingDeletion = course
                                        } label: {
                                            Label("删除课程", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 1320, alignment: .leading)
            }
            .navigationTitle("我的课程")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("导入课程", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.json],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                Task { await model.importCourses(from: urls) }
            }
            .alert(
                "删除课程？",
                isPresented: Binding(
                    get: { coursePendingDeletion != nil },
                    set: { if !$0 { coursePendingDeletion = nil } }
                ),
                presenting: coursePendingDeletion
            ) { course in
                Button("删除“\(course.title)”", role: .destructive) {
                    Task { await model.deleteCourse(course) }
                    coursePendingDeletion = nil
                }
                Button("取消", role: .cancel) {
                    coursePendingDeletion = nil
                }
            } message: { _ in
                Text("该课程的进度、复习计划、收藏和笔记也会被删除。")
            }
        }
    }

    private var catalogHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("课程资料库")
                    .font(.largeTitle.weight(.bold))
                Text("统一管理章节、知识点和题目。新的解析结果可随时导入，无需修改源码。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    isImporting = true
                } label: {
                    Label("导入 chapters.json", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            }
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 72))
                .foregroundStyle(.indigo)
                .symbolRenderingMode(.hierarchical)
        }
        .scholarCard()
    }
}
