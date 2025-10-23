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
    @Published var indoorOutdoorScore: Double = 50
    
    // For UI state
    @Published var selectedDay: String? = nil
    @Published var startTime: Date = Date()
    @Published var endTime: Date = Date()
    
    // Track if email came from auth provider
    private var emailFromProvider: String? = nil
    private var isProviderEmail: Bool = false
    
    let db = Firestore.firestore(database: "default")

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    // MARK: - Computed Properties
    var isEmailFromProvider: Bool {
        return isProviderEmail
    }
    
    // MARK: - Initialization
    func initializeWithAuthUser(_ user: FirebaseAuth.User?) {
        if let user = user {
            // Get display name
            name = user.displayName ?? ""
            
            // Get email from provider
            if let userEmail = user.email, !userEmail.isEmpty {
                email = userEmail
                emailFromProvider = userEmail
                isProviderEmail = true
            } else {
                isProviderEmail = false
            }
            
            print("📧 Email initialized from provider: \(email)")
            print("🔒 Email from provider locked: \(isProviderEmail)")
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
    
    // MARK: - Step-by-Step Validation
    func validateCurrentStep(_ step: Int) -> (isValid: Bool, message: String) {
        switch step {
        case 0:
            return validateBasicInfo()
        case 1:
            return validatePersonalDetails()
        case 2:
            return validatePreferences()
        case 3:
            return validateFreeTimeSlots()
        case 4:
            return validateAllFields()
        default:
            return (true, "")
        }
    }
    
    // Step 0: Basic Info Validation
    private func validateBasicInfo() -> (isValid: Bool, message: String) {
        // Validate name - trim whitespace and check if empty
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return (false, "Please enter your name (spaces only are not allowed)")
        }
        
        // Validate email
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            return (false, "Please enter your email")
        }
        
        // Basic email format validation
        if !isValidEmail(trimmedEmail) {
            return (false, "Please enter a valid email address")
        }
        
        // Validate major
        if major.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "Please select your major")
        }
        
        return (true, "")
    }
    
    // Step 1: Personal Details Validation
    private func validatePersonalDetails() -> (isValid: Bool, message: String) {
        if gender == nil {
            return (false, "Please select your gender")
        }
        
        // Validate age (must be between 10 and 120 years old)
        let age = calculateAge()
        if age < 10 {
            return (false, "You must be at least 10 years old to register")
        }
        if age > 120 {
            return (false, "Please enter a valid birth date")
        }
        
        return (true, "")
    }
    
    // Step 2: Preferences Validation
    private func validatePreferences() -> (isValid: Bool, message: String) {
        if favoriteCategories.isEmpty {
            return (false, "Please select at least one category")
        }
        return (true, "")
    }
    
    // Step 3: Free Time Slots Validation
    private func validateFreeTimeSlots() -> (isValid: Bool, message: String) {
        if freeTimeSlots.isEmpty {
            return (false, "Please add at least one free time slot")
        }
        return (true, "")
    }
    
    // Step 4: Final Validation (all fields)
    private func validateAllFields() -> (isValid: Bool, message: String) {
        // Validate basic info
        let basicValidation = validateBasicInfo()
        if !basicValidation.isValid {
            return basicValidation
        }
        
        // Validate personal details
        let personalValidation = validatePersonalDetails()
        if !personalValidation.isValid {
            return personalValidation
        }
        
        // Validate preferences
        let preferencesValidation = validatePreferences()
        if !preferencesValidation.isValid {
            return preferencesValidation
        }
        
        // Validate free time slots
        let slotsValidation = validateFreeTimeSlots()
        if !slotsValidation.isValid {
            return slotsValidation
        }
        
        return (true, "All fields are valid")
    }
    
    // MARK: - Helper: Email Validation
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
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
        
        // Final validation before saving
        let validation = validateAllFields()
        if !validation.isValid {
            throw NSError(domain: "ValidationError", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: validation.message])
        }
        
        print("Validation passed")
        
        // Trim whitespace from name and email before saving
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get photo URL from current user
        let photoUrl = Auth.auth().currentUser?.photoURL?.absoluteString ?? ""
        let age = calculateAge()
        
        // Convert free time slots to array of dictionaries
        let freeTimeSlotsData = freeTimeSlots
        
        // Prepare data matching Flutter UserData model structure
        let userData: [String: Any] = [
            "profile": [
                "name": trimmedName,
                "email": trimmedEmail,
                "photo": photoUrl,
                "major": major,
                "gender": gender ?? "",
                "age": age,
                "created": FieldValue.serverTimestamp(),
                "last_active": FieldValue.serverTimestamp()
            ],
            "preferences": [
                "indoor_outdoor_score": Int(indoorOutdoorScore),
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

            // Log analytics
            AnalyticsService.shared.setUserId(uid)
            AnalyticsService.shared.logOutdoorIndoorPreference(Int(indoorOutdoorScore))
            
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
        isProviderEmail = false
        major = ""
        gender = nil
        birthDate = Date()
        favoriteCategories = []
        freeTimeSlots = []
        selectedDay = nil
        startTime = Date()
        endTime = Date()
        indoorOutdoorScore = 50
    }
}
