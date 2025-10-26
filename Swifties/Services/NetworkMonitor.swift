import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    @Published private(set) var isConnected: Bool = true

    private init() {
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    func currentConnectionAvailable() -> Bool {
        return isConnected
    }
}
