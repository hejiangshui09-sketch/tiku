import Combine
import Foundation
@preconcurrency import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected = true
    @Published private(set) var connectionName = "正在检测"

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ScholarPad.NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            let connectionName: String
            if path.usesInterfaceType(.wifi) {
                connectionName = "Wi-Fi"
            } else if path.usesInterfaceType(.cellular) {
                connectionName = "蜂窝网络"
            } else {
                connectionName = isConnected ? "已连接" : "离线"
            }
            Task { @MainActor in
                self?.isConnected = isConnected
                self?.connectionName = connectionName
            }
        }
        monitor.start(queue: queue)
    }
}
