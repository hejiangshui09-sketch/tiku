import SwiftUI

struct OnlineLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingAddResource = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    cloudResourceSection

                    if let catalog = model.remoteCatalog {
                        catalogView(catalog)
                    } else {
                        setupView
                    }
                }
                .padding(28)
                .frame(maxWidth: 1320, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("在线资源库")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAddResource = true
                    } label: {
                        Label("添加网盘资源", systemImage: "plus")
                    }
                    Button {
                        Task { await model.refreshRemoteCatalog() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.catalogURLString.isEmpty || !model.network.isConnected)
                }
            }
            .sheet(isPresented: $showingAddResource) {
                AddCloudResourceSheet()
            }
        }
    }

    private var cloudResourceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeading(
                    title: "我的网盘资源",
                    subtitle: "保存网盘分享页、视频直链、音频、图片和在线文档"
                )
                Button {
                    showingAddResource = true
                } label: {
                    Label("添加资源", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if model.cloudResources.isEmpty {
                HStack(spacing: 18) {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.system(size: 42))
                        .foregroundStyle(.indigo)
                        .symbolRenderingMode(.hierarchical)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("还没有保存网盘资源")
                            .font(.headline)
                        Text("普通分享链接会在应用内打开；可直接访问的 MP4、M3U8 等视频地址可使用系统播放器。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .scholarCard()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(model.cloudResources.sorted { $0.createdAt > $1.createdAt }) { resource in
                        NavigationLink {
                            ResourceViewerView(resource: resource.learningResource, localURL: nil)
                        } label: {
                            CloudResourceCard(resource: resource)
                        }
                        .buttonStyle(.scaling)
                        .contextMenu {
                            ShareLink(item: resource.url) {
                                Label("分享链接", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                model.deleteCloudResource(resource)
                            } label: {
                                Label("删除资源", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 18) {
            Image(systemName: "network")
                .font(.system(size: 52))
                .foregroundStyle(.indigo)
                .symbolRenderingMode(.hierarchical)
            Text("连接在线课程目录")
                .font(.title2.weight(.bold))
            Text("在设置中配置课程目录地址，即可浏览、安装并离线学习多门课程。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button {
                model.activateSection(.settings)
            } label: {
                Label("前往设置", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .scholarCard()
    }

    private func catalogView(_ catalog: RemoteCourseCatalog) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("在线书籍目录")
                        .font(.title2.weight(.bold))
                    Text("\(catalog.courses.count) 本在线书籍 · 目录版本 \(catalog.version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                ForEach(catalog.courses) { descriptor in
                    RemoteCourseCard(descriptor: descriptor)
                }
            }
        }
    }
}

private struct CloudResourceCard: View {
    let resource: CloudResource

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: resource.kind.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 5) {
                Text(resource.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(resourceDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scholarCard(padding: 16)
    }

    private var resourceDetail: String {
        guard let detail = resource.detail, !detail.isEmpty else {
            return resource.url.host ?? resource.kind.title
        }
        return detail
    }
}

private struct AddCloudResourceSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var urlString = ""
    @State private var detail = ""
    @State private var kind: LearningResourceKind = .link

    var body: some View {
        NavigationStack {
            Form {
                Section("资源信息") {
                    TextField("资源名称", text: $title)
                    TextField("https://网盘分享链接或视频直链", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("备注，例如提取码、讲师或内容说明", text: $detail, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("打开方式") {
                    Picker("资源类型", selection: $kind) {
                        ForEach(
                            [LearningResourceKind.link, .video, .audio, .document, .image],
                            id: \.self
                        ) { item in
                            Label(item.title, systemImage: item.symbol).tag(item)
                        }
                    }
                    Text(kind == .video
                         ? "视频类型需要可直接播放的视频地址；网盘分享页面请选择“链接”。"
                         : "网盘分享页面会使用应用内网页打开，登录和提取码由对应网盘处理。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("添加网盘资源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        model.addCloudResource(title: title, urlString: urlString, kind: kind, detail: detail)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                              || urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
                Label(model.isInstalled(descriptor) ? "更新离线书籍" : "安装到我的书柜", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(descriptor.accent.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .scholarCard()
    }
}
