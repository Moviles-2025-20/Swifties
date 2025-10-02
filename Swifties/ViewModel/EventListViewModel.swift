//
//  EventListViewModel.swift
//  Swifties
//
//  Created by Imac on 1/10/25.
//

import Foundation
import FirebaseFirestore
import Combine

class EventListViewModel: ObservableObject {
    
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db: Firestore
    
    init() {
        // Inicializamos Firestore y configuramos settings
        let firestore = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true // cache offline opcional
        firestore.settings = settings
        self.db = firestore
    }
    
    func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        db.collection("events").getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error al cargar eventos: \(error.localizedDescription)"
                    print(self.errorMessage ?? "")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No se encontraron eventos"
                    return
                }
                
                // Decodificación manual de los documentos
                self.events = documents.compactMap { doc in
                    let data = doc.data()
                    
                    guard let title = data["title"] as? String,
                          let name = data["name"] as? String,
                          let description = data["description"] as? String,
                          let type = data["type"] as? String,
                          let category = data["category"] as? String,
                          let active = data["active"] as? Bool else {
                        print("Documento incompleto: \(doc.documentID)")
                        return nil // esto filtra documentos incompletos
                    }

                    return Event(
                        id: doc.documentID,
                        title: title,
                        name: name,
                        description: description,
                        type: type,
                        category: category,
                        active: active,
                        eventType: [], // completa con default o tu data real
                        location: Event.Location(city: "", type: "", address: "", coordinates: []),
                        schedule: Event.Schedule(days: [], times: []),
                        metadata: Event.Metadata(imageUrl: "", tags: [], durationMinutes: 0, cost: ""),
                        stats: Event.EventStats(popularity: 0, totalCompletions: 0, rating: 0),
                        weatherDependent: false,
                        created: Timestamp(date: Date())
                    )
                }

                
                print("Eventos cargados: \(self.events.count)")
            }
        }
    }
}
