//
//  EventListViewModel.swift
//  Swifties
//
//  Created by Imac  on 1/10/25.
//

// EventListViewModel.swift
import Foundation
import FirebaseFirestore
import Combine

class EventListViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()

    func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        db.collection("events").getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Error al cargar eventos: \(error.localizedDescription)"
                    print(self?.errorMessage ?? "")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.errorMessage = "No se encontraron eventos"
                    return
                }
                
                self?.events = documents.compactMap { doc in
                    let data = doc.data()
                    
                    // COMENTADO TEMPORALMENTE PARA TESTING
                    // Descomentar cuando quieras filtrar solo eventos activos
                    // guard data["active"] as? Bool ?? false else {
                    //     return nil
                    // }
                    
                    return Event(
                        id: doc.documentID,
                        name: data["name"] as? String ?? "Sin nombre",
                        description: data["description"] as? String ?? "Sin descripción",
                        category: data["category"] as? String ?? "Sin categoría",
                        active: data["active"] as? Bool ?? false,
                        title: data["title"] as? String ?? data["name"] as? String ?? "Sin título",
                        eventType: data["eventType"] as? [String] ?? data["EventType"] as? [String] ?? []
                    )
                }
                
                print("Eventos cargados: \(self?.events.count ?? 0)")
            }
        }
    }
}
