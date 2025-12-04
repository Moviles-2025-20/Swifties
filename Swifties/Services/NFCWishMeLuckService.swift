//
//  NFCWishMeLuckService.swift
//  Swifties
//
//  NFC Service for triggering Wish Me Luck feature
//

import Foundation
import CoreNFC
import UIKit

class NFCWishMeLuckService: NSObject {
    static let shared = NFCWishMeLuckService()
    
    private var nfcSession: NFCNDEFReaderSession?
    
    // Callback when NFC tag is successfully read
    var onNFCTagRead: (() -> Void)?
    
    // Callback for errors
    var onError: ((String) -> Void)?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Check NFC Availability
    
    func isNFCAvailable() -> Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
    
    // MARK: - Start NFC Session
    
    func startNFCSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            onError?("NFC is not available on this device")
            print("❌ NFC not available on this device")
            return
        }
        
        nfcSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        
        nfcSession?.alertMessage = "Hold your iPhone near the Wish Me Luck NFC tag"
        nfcSession?.begin()
        
        print("NFC session started")
    }
    
    // MARK: - Stop NFC Session
    
    func stopNFCSession() {
        nfcSession?.invalidate()
        print("!!!! NFC session stopped")
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCWishMeLuckService: NFCNDEFReaderSessionDelegate {
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorFirstNDEFTagRead:
                print("✅ NFC tag read successfully")
                // Success case - tag was read
                return
                
            case .readerSessionInvalidationErrorUserCanceled:
                print("⚠️ User canceled NFC session")
                return
                
            default:
                print("❌ NFC error: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.onError?("Failed to read NFC tag: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        print("NFC tag detected with \(messages.count) message(s)")
        
        // Check if any message contains our Wish Me Luck identifier
        for message in messages {
            for record in message.records {
                if let payload = String(data: record.payload, encoding: .utf8) {
                    print("   Payload: \(payload)")
                    
                    // Check if this is our Wish Me Luck tag
                    if payload.contains("wishmeLuck") ||
                       payload.contains("WishMeLuck") ||
                       record.typeNameFormat == .nfcWellKnown {
                        
                        session.alertMessage = "🍀 Wish Me Luck activated!"
                        
                        // Trigger the wish on main thread
                        DispatchQueue.main.async { [weak self] in
                            self?.onNFCTagRead?()
                        }
                        
                        // Invalidate session after success
                        session.invalidate()
                        return
                    }
                }
            }
        }
        
        // If we get here, tag wasn't recognized
        session.alertMessage = "❌ This is not a Wish Me Luck tag"
        session.invalidate()
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("NFC session became active")
    }
}
