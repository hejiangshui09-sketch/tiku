import SwiftUI

struct OnlineLibraryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if let catalog = model.remoteCatalog {
                    catalogView(catalog)
                } else {
                    setupView
                }
            }
            .navigationTitle("在线课程库")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refreshRemoteCatalog() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.catalogURLString.isEmpty || !model.network.isConnected)
                }
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 22) {
            Image(systemName: "network")
                .font(.system(size: 72))
                .foregroundStyle(.indigo)
                .symbolRenderingMode(.hierarchical)
            Text("连接在线课程目录")
                .font(.largeTitle.weight(.bold))
            Text("在设置中配置课程目录地址，即可浏览、安装并离线学习多门课程。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button {
                model.selectedSection = .settings
            } label: {
                Label("前往设置", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }

    private func catalogView(_ catalog: RemoteCourseCatalog) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("发现新课程")
                            .font(.largeTitle.weight(.bold))
                        Text("\(catalog.courses.count) 门在线课程 · 目录版本 \(catalog.version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .scholarCard()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                    ForEach(catalog.courses) { descriptor in
                        RemoteCourseCard(descriptor: descriptor)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1320, alignment: .leading)
        }
    }
}

private struct RemoteCourseCard: View {
    @EnvironmentObject private var model: AppModel
    let descriptor: RemoteCourseDescriptor

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "icloud.and.arrow.down.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(descriptor.accent.gradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                Spacer()
                Text(model.isInstalled(descriptor) ? "已安装" : "在线")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(model.isInstalled(descriptor) ? .green : descriptor.accent.color)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(descriptor.subject)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(descriptor.accent.color)
                Text(descriptor.title)
                    .font(.title3.weight(.bold))
                Text(descriptor.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            HStack(spacing: 14) {
                if let chapterCount = descriptor.chapterCount {
                    Label("\(chapterCount) 章", systemImage: "list.number")
                }
                if let questionCount = descriptor.questionCount {
                    Label("\(questionCount) 题", systemImage: "checkmark.circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                Task { await model.installRemoteCourse(descriptor) }
            } label: {
                Label(model.isInstalled(descriptor) ? "更新离线课程" : "安装到我的课程", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(descriptor.accent.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scholarCard()
    }
}
