//
//  EventNetworkService.swift
//  Swifties
//
//  Created by Imac on 25/10/25.
//  Modified with multithreading support
//

import Foundation
import FirebaseFirestore

class EventNetworkService {
    static let shared = EventNetworkService()
    
    private let db = Firestore.firestore(database: "default")
    private let threadManager = ThreadManager.shared
    
    private init() {
        let settings = FirestoreSettings()
        db.settings = settings
    }
    
    func fetchEvents(completion: @escaping (Result<[Event], Error>) -> Void) {
        // Ejecutar la petición de red en background
        threadManager.executeNetworkOperation {
            self.db.collection("events").getDocuments { snapshot, error in
                // Firestore ya ejecuta el completion en su propia cola
                // Procesamos los datos en background
                self.threadManager.executeNetworkOperation {
                    if let error = error {
                        // Retornar al main thread para actualizar UI
                        self.threadManager.executeOnMain {
                            completion(.failure(error))
                        }
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        let error = NSError(
                            domain: "EventNetworkService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No documents found"]
                        )
                        self.threadManager.executeOnMain {
                            completion(.failure(error))
                        }
                        return
                    }
                    
                    // Procesar documentos en background (operación costosa)
                    let events = documents.compactMap { EventFactory.createEvent(from: $0) }
                    print("\(events.count) events fetched from Firestore (background thread)")
                    
                    // Retornar al main thread
                    self.threadManager.executeOnMain {
                        completion(.success(events))
                    }
                }
            }
        }
    }
    
    /// Versión alternativa con async/await (iOS 15+)
    @available(iOS 15.0, *)
    func fetchEventsAsync() async throws -> [Event] {
        return try await withCheckedThrowingContinuation { continuation in
            fetchEvents { result in
                continuation.resume(with: result)
            }
        }
    }
}
