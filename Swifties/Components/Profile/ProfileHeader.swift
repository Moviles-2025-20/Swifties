//
//
//  Created by Natalia Villegas Calderón on 27/09/25.
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// Profile Header Component
struct ProfileHeader: View {
    let avatar_url: String?
    let name: String
    let major: String
    let age: Int
    let indoor_outdoor_score: Int
    
    @State private var showSourceMenu = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isUploading = false
    
    private var personalityLabel: String {
        if indoor_outdoor_score < 50 { return "Insider" }
        if indoor_outdoor_score > 50 { return "Outsider" }
        return "Neutral"
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Profile Image
            Group {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                } else if let avatar_url, let url = URL(string: avatar_url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 90, height: 90)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 90, height: 90)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .foregroundColor(.gray)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 90)
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.gray)
                }
            }
            .contextMenu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Choose from Photo Library", systemImage: "photo.on.rectangle")
                }
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Major - \(major)")
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                Text("Age - \(age)")
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                Text("Personality: \(personalityLabel) (\(indoor_outdoor_score)%)")
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                BipolarProgressBar(value: indoor_outdoor_score)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                    await uploadAndSave(image: uiImage)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, image: $selectedImage)
                .ignoresSafeArea()
        }
    }
    
    @MainActor
    private func uploadAndSave(image: UIImage) async {
        self.selectedImage = image
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        isUploading = true
        defer { isUploading = false }

        let filename = "users/\(uid)/avatar_\(uid).jpg"
        let storageRef = Storage.storage().reference(withPath: filename)
        do {
            _ = try await storageRef.putDataAsync(data, metadata: nil)
            let url = try await storageRef.downloadURL()
            // Save reference path to Firestore under profile.photo as a String containing the storage path
            let db = Firestore.firestore(database: "default")
            let userRef = db.collection("users").document(uid)
            try await userRef.setData(["profile": ["photo": url.absoluteString]], merge: true)
        } catch {
            print("Failed to upload or save photo: \(error)")
        }
    }
}

// MARK: - Bipolar progress bar (-100 to 100) starting at center
private struct BipolarProgressBar: View {
    let value: Int // expected range: 0...100
    var height: CGFloat = 8
    var negativeColor: Color = Color("appRed")
    var positiveColor: Color = Color("appBlue")
    
    var body: some View {
        GeometryReader { geo in
            let mid = geo.size.width / 2
            let floatValue = (CGFloat(value) - 50.0) / 50.0
            let magnitude = min(max(abs(floatValue), 0), 1)
            let fillW = mid * magnitude
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: height + 2)
                
                // Fill from center to the right for positive values
                if value > 50 {
                    Capsule()
                        .fill(positiveColor)
                        .frame(width: fillW, height: height)
                        .offset(x: mid)
                }
                
                // Fill from center to the left for negative values
                if value < 50 {
                    Capsule()
                        .fill(negativeColor)
                        .frame(width: fillW, height: height)
                        .offset(x: mid - fillW)
                }
            }
        }
        .frame(height: height)
    }
}
