//
//  SwiftiesApp.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 24/09/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        FirebaseApp.configure()
        
        let db = Firestore.firestore(database: "default")
        // Test connection
        db.collection("test").document("connection").setData(["test": "value"]) { error in
            if let error = error {
                print("❌ Firestore connection failed: \(error.localizedDescription)")
            } else {
                print("✅ Firestore connected successfully!")
            }
        }
        return true
    }
    // Restrict the app to portrait mode only
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }


@main
struct SwiftiesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if Auth.auth().currentUser != nil {
                    MainView()
                }else{
                    StartView()
                }
            }
            .environmentObject(authViewModel)
            // BEFORE
            //@State private var isLoading = true

            //var body: some Scene {
            //WindowGroup {
            //if isLoading {
            //LoadingView()
            //.onAppear {
            // Cambiar a EventListView después de 2 segundos
            //DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            //withAnimation {
            //    isLoading = false
            //}
            //}
            //}
            //} else {
            //HomeView()
            //EventListView(viewModel: EventListViewModel())
            //}
         }
       }
    }
}
