// RegisterViewModel.swift
// Swifties
// Created by Natalia Villegas Calderón on 2/10/25.

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import FirebaseCore

@MainActor
class RegisterViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var major: String = ""
    @Published var gender: String? = nil
    @Published var birthDate: Date = Date()
    @Published var favoriteCategories: [String] = []
    @Published var freeTimeSlots: [[String: String]] = []
    @Published var isLoading: Bool = false
    @Published var indoorOutdoorScore: Double = 0 // NEW: Indoor/Outdoor preference
    
    // For UI state
    @Published var selectedDay: String? = nil
    @Published var startTime: Date = Date()
    @Published var endTime: Date = Date()
    
    // Track if email came from auth provider
    private var emailFromProvider: String? = nil
    let db = Firestore.firestore(database: "default")

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    // MARK: - Computed Properties
    var isEmailFromProvider: Bool {
        guard let providerEmail = emailFromProvider else {
            return false
        }
        return !providerEmail.isEmpty && email == providerEmail
    }
    
    // MARK: - Initialization
    func initializeWithAuthUser(_ user: FirebaseAuth.User?) {
        if let user = user {
            name = user.displayName ?? ""
            email = user.email ?? ""
            emailFromProvider = user.email
        }
    }
    
    // MARK: - Category Management
    func toggleCategory(_ category: String) {
        if let index = favoriteCategories.firstIndex(of: category) {
            favoriteCategories.remove(at: index)
        } else {
            favoriteCategories.append(category)
        }
    }
    
    // MARK: - Free Time Slot Management
    func addFreeTimeSlot() {
        guard let day = selectedDay else { return }
        
        let startTimeString = dateFormatter.string(from: startTime)
        let endTimeString = dateFormatter.string(from: endTime)
        
        let slot: [String: String] = [
            "day": day,
            "start": startTimeString,
            "end": endTimeString
        ]
        
        freeTimeSlots.append(slot)
        selectedDay = nil
    }
    
    func removeFreeTimeSlot(at index: Int) {
        guard index >= 0 && index < freeTimeSlots.count else { return }
        freeTimeSlots.remove(at: index)
    }
    
    func updateFreeTimeSlot(at index: Int, start: String, end: String) {
        guard index >= 0 && index < freeTimeSlots.count else { return }
        freeTimeSlots[index]["start"] = start
        freeTimeSlots[index]["end"] = end
    }
    
    // MARK: - Age Calculation
    func calculateAge() -> Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year ?? 0
    }
    
    // MARK: - Validation
    func validateCurrentStep(_ step: Int) -> (isValid: Bool, message: String) {
        switch step {
        case 0:
            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                return (false, "Please enter your name")
            }
            if email.trimmingCharacters(in: .whitespaces).isEmpty {
                return (false, "Please enter your email")
            }
            if major.trimmingCharacters(in: .whitespaces).isEmpty {
                return (false, "Please select your major")
            }
            return (true, "")
        case 1:
            if gender == nil {
                return (false, "Please select your gender")
            }
            return (true, "")
        case 2:
            if favoriteCategories.isEmpty {
                return (false, "Please select at least one preference")
            }
            return (true, "")
        case 3:
            if freeTimeSlots.isEmpty {
                return (false, "Please add at least one free time slot")
            }
            return (true, "")
        case 4:
            return validateAllFields()
        default:
            return (true, "")
        }
    }
    
    private func validateAllFields() -> (isValid: Bool, message: String) {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return (false, "Name is required")
        }
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            return (false, "Email is required")
        }
        if major.trimmingCharacters(in: .whitespaces).isEmpty {
            return (false, "Major is required")
        }
        if gender == nil {
            return (false, "Gender is required")
        }
        if favoriteCategories.isEmpty {
            return (false, "At least one preference is required")
        }
        if freeTimeSlots.isEmpty {
            return (false, "At least one free time slot is required")
        }
        return (true, "")
    }
    
    // MARK: - Save to Firebase
    func saveUserData() async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ERROR: No authenticated user found")
            throw NSError(domain: "AuthError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])
        }
        
        print("User ID: \(uid)")
        
        // Validate all fields
        let validation = validateAllFields()
        guard validation.isValid else {
            print("ERROR: Validation failed - \(validation.message)")
            throw NSError(domain: "ValidationError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: validation.message])
        }
        
        print("Validation passed")
        
        // Get photo URL from current user
        let photoUrl = Auth.auth().currentUser?.photoURL?.absoluteString ?? ""
        let age = calculateAge()
        
        // Convert free time slots to array of dictionaries
        let freeTimeSlotsData = freeTimeSlots
        
        // Prepare data matching Flutter UserData model structure
        let userData: [String: Any] = [
            "profile": [
                "name": name,
                "email": email,
                "photo": photoUrl,
                "major": major,
                "gender": gender ?? "",
                "age": age,
                "created": FieldValue.serverTimestamp(),
                "last_active": FieldValue.serverTimestamp()
            ],
            "preferences": [
                "indoor_outdoor_score": Int(indoorOutdoorScore), // NEW: Added indoor/outdoor score
                "favorite_categories": favoriteCategories,
                "notifications": [
                    "free_time_slots": freeTimeSlotsData
                ]
            ]
        ]
        
        print("Attempting to save data to Firestore...")
        
        do {
            try await db.collection("users").document(uid).setData(userData, merge: true)
            print("✅ Successfully saved to Firestore!")
        } catch {
            print("❌ Firestore save error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Reset
    func reset() {
        name = ""
        email = ""
        emailFromProvider = nil
        major = ""
        gender = nil
        birthDate = Date()
        favoriteCategories = []
        freeTimeSlots = []
        selectedDay = nil
        startTime = Date()
        endTime = Date()
        indoorOutdoorScore = 50 // Reset to default
    }
}
