//
//  NetworkMonitorService.swift
//  Swifties
//
//  Created by Imac  on 25/10/25.
//

import Foundation
import Network

class NetworkMonitorService {
    static let shared = NetworkMonitorService()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected: Bool = true
    private(set) var connectionType: NWInterface.InterfaceType?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.connectionType = path.availableInterfaces.first?.type
            
            DispatchQueue.main.async {
                if self?.isConnected == true {
                    print("Conexión a Internet disponible")
                } else {
                    print("Sin conexión a Internet")
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
