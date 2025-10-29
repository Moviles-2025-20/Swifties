import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue", qos: .background)

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var connectionType: NWInterface.InterfaceType?

    private init() {
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = (path.status == .satisfied)
                self?.connectionType = path.availableInterfaces.first?.type
                
                if path.status == .satisfied {
                    print("Internet connection available")
                } else {
                    print("No Internet connection")
                }
            }
        }
        monitor.start(queue: queue)
    }

    func currentConnectionAvailable() -> Bool {
        return isConnected
    }

    deinit {
        monitor.cancel()
    }
}
