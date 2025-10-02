//
//  FirestoreTest.swift
//  Swifties
//
//  Created by Imac  on 2/10/25.
//

//  FirestoreTest.swift
//  Swifties
//
//  Created by Carol on 2/10/25.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

class FirestoreTest {

    private let db = Firestore.firestore()

    func testConnection() {
        print("🔹 Probando conexión a Firestore...")

        db.collection("events").getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error al conectar: \(error.localizedDescription)")
                return
            }

            guard let snapshot = snapshot else {
                print("❌ No se recibieron documentos.")
                return
            }

            print("✅ Conexión exitosa. Documentos encontrados: \(snapshot.documents.count)")

            for doc in snapshot.documents {
                print("Documento ID: \(doc.documentID), Data: \(doc.data())")
            }
        }
    }
}
