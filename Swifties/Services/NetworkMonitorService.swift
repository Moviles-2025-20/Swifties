import Foundation
import Network
import Combine

class NetworkMonitorService: ObservableObject  {
    static let shared = NetworkMonitorService()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published private(set) var isConnected: Bool = true
    private(set) var connectionType: NWInterface.InterfaceType?
    private var hasStarted: Bool = false
    
    func startMonitoring() {
        guard !hasStarted else { return }
        hasStarted = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isConnected = path.status == .satisfied
                self.connectionType = path.availableInterfaces.first?.type
                if self.isConnected {
                    print("Internet connection available")
                } else {
                    print("No Internet connection")
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
}
