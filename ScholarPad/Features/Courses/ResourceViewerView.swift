@preconcurrency import AVKit
import Foundation
import SwiftUI
import UIKit
@preconcurrency import WebKit

struct ResourceViewerView: View {
    let resource: LearningResource
    let localURL: URL?

    private var contentURL: URL {
        localURL ?? resource.url
    }

    var body: some View {
        Group {
            switch resource.kind {
            case .video, .audio:
                MediaPlayerView(url: contentURL)
                    .background(Color.black)
            case .image:
                imageViewer
            case .document, .link:
                WebResourceView(url: contentURL)
            }
        }
        .navigationTitle(resource.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: contentURL) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var imageViewer: some View {
        ScrollView([.horizontal, .vertical]) {
            Group {
                if contentURL.isFileURL, let image = UIImage(contentsOfFile: contentURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    AsyncImage(url: contentURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView("正在加载图片…")
                                .frame(minWidth: 500, minHeight: 500)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            ContentUnavailableView {
                                Label("图片加载失败", systemImage: "exclamationmark.triangle")
                            } description: {
                                Text("请检查网络连接或资源地址")
                            }
                            .frame(minWidth: 500, minHeight: 500)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(ScholarTheme.page)
    }
}

private struct MediaPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        guard (controller.player?.currentItem?.asset as? AVURLAsset)?.url != url else { return }
        controller.player = AVPlayer(url: url)
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.player?.pause()
    }

    final class Coordinator {}
}

private struct WebResourceView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.loadedURL = url
        load(url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        load(url, in: webView)
    }

    final class Coordinator {
        var loadedURL: URL?
    }

    private func load(_ url: URL, in webView: WKWebView) {
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }
}
