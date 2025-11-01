//
//  UserDefaultsService.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 31/10/25.
//
import Foundation

class UserDefaultsService {
    static let shared = UserDefaultsService()
    
    private let defaults = UserDefaults.standard
    
    // Keys for storing REGISTRATION data (not events)
    private enum Keys {
        static let registrationData = "pending_registration_data"
        static let hasPendingRegistration = "has_pending_registration"
        static let lastSaveAttempt = "last_save_attempt"
        static let registrationCompleted = "registration_completed_locally"
    }
    
    private init() {}
    
    // MARK: - Save Registration Data Locally
    func saveRegistrationData(_ data: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            defaults.set(jsonData, forKey: Keys.registrationData)
            defaults.set(true, forKey: Keys.hasPendingRegistration)
            defaults.set(Date(), forKey: Keys.lastSaveAttempt)
            print("✅ Registration data saved to UserDefaults")
        } catch {
            print("❌ Failed to save registration data to UserDefaults: \(error)")
        }
    }
    
    // MARK: - Mark Registration as Completed Locally
    func markRegistrationCompleted() {
        defaults.set(true, forKey: Keys.registrationCompleted)
        print("✅ Registration marked as completed locally")
    }
    
    // MARK: - Check if Registration was Completed Locally
    func hasCompletedRegistrationLocally() -> Bool {
        return defaults.bool(forKey: Keys.registrationCompleted)
    }
    
    // MARK: - Get Pending Registration Data
    func getPendingRegistrationData() -> [String: Any]? {
        guard hasPendingRegistration() else { return nil }
        
        guard let jsonData = defaults.data(forKey: Keys.registrationData) else {
            print("⚠️ No registration data found in UserDefaults")
            return nil
        }
        
        do {
            let data = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
            print("✅ Retrieved registration data from UserDefaults")
            return data
        } catch {
            print("❌ Failed to retrieve registration data from UserDefaults: \(error)")
            return nil
        }
    }
    
    // MARK: - Check if there's pending registration
    func hasPendingRegistration() -> Bool {
        return defaults.bool(forKey: Keys.hasPendingRegistration)
    }
    
    // MARK: - Clear Registration Data (after successful upload)
    func clearRegistrationData() {
        defaults.removeObject(forKey: Keys.registrationData)
        defaults.set(false, forKey: Keys.hasPendingRegistration)
        defaults.removeObject(forKey: Keys.lastSaveAttempt)
        print("✅ Cleared pending registration data from UserDefaults")
        
        // NOTE: We DON'T clear registrationCompleted here
        // because we want to remember the user completed registration
        // even after data is synced
    }
    
    // MARK: - Clear All Registration Data (on sign out)
    func clearAllData() {
        defaults.removeObject(forKey: Keys.registrationData)
        defaults.removeObject(forKey: Keys.hasPendingRegistration)
        defaults.removeObject(forKey: Keys.lastSaveAttempt)
        defaults.removeObject(forKey: Keys.registrationCompleted)
        print("✅ Cleared all registration data from UserDefaults")
    }
    
    // MARK: - Get Last Save Attempt
    func getLastSaveAttempt() -> Date? {
        return defaults.object(forKey: Keys.lastSaveAttempt) as? Date
    }
    
    // MARK: - Debug Info
    func printDebugInfo() {
        print("\n=== UserDefaults Debug Info (REGISTRATION) ===")
        print("Has Pending Registration: \(hasPendingRegistration())")
        print("Registration Completed Locally: \(hasCompletedRegistrationLocally())")
        print("Last Save Attempt: \(getLastSaveAttempt()?.description ?? "None")")
        
        if let data = getPendingRegistrationData() {
            print("Pending Data Keys: \(data.keys.joined(separator: ", "))")
            if let profile = data["profile"] as? [String: Any] {
                print("  Profile Name: \(profile["name"] ?? "N/A")")
                print("  Profile Email: \(profile["email"] ?? "N/A")")
            }
            if let prefs = data["preferences"] as? [String: Any],
               let notifications = prefs["notifications"] as? [String: Any],
               let slots = notifications["free_time_slots"] as? [[String: String]] {
                print("  Free Time Slots: \(slots.count)")
            }
        }
        
        print("=============================================\n")
    }
    // MARK: - Extra methods for saving the session when you delete and reinstall
    
    private func registrationCompletedKey(uid: String) -> String {
        return "registration_completed_\(uid)"
    }
    
    func hasCompletedRegistration(uid: String) -> Bool {
        return UserDefaults.standard.bool(forKey: registrationCompletedKey(uid: uid))
    }
    
    func cacheRegistrationStatus(uid: String, completed: Bool) {
        UserDefaults.standard.set(completed, forKey: registrationCompletedKey(uid: uid))
        print(" Cached registration status for \(uid): \(completed)")
    }
    
}
