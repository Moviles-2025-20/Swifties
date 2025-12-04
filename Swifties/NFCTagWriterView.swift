//
//  NFCTagWriterView.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 4/12/25.
//

import SwiftUI
import CoreNFC
import Combine

struct NFCTagWriterView: View {
    @StateObject private var writer = NFCWriter()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text("NFC Tag Writer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Write Wish Me Luck data to your NFC tag")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Image(systemName: "wave.3.right.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions:")
                        .font(.headline)
                    
                    Text("1. Make sure you have an NFC tag (NTAG213/215/216)")
                    Text("2. Tap the button below")
                    Text("3. Hold your iPhone near the NFC tag")
                    Text("4. Wait for confirmation")
                    Text("5. Tag will remain rewritable for future updates")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Warning about read-only tags
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Tags are kept rewritable - you can update them anytime!")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                
                Button {
                    writer.writeToNFCTag()
                } label: {
                    HStack {
                        Image(systemName: "pencil.circle.fill")
                        Text("Write to NFC Tag")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(writer.isWriting ? Color.gray : Color.blue)
                    .cornerRadius(16)
                }
                .disabled(writer.isWriting)
                .padding(.horizontal)
                
                if writer.isWriting {
                    ProgressView("Writing to tag...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: writer.statusMessage) { _, newValue in
                if !newValue.isEmpty {
                    alertMessage = newValue
                    showAlert = true
                }
            }
            .alert("NFC Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    writer.statusMessage = ""
                    // Auto-dismiss on success
                    if alertMessage.contains("✅") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

class NFCWriter: NSObject, ObservableObject {
    @Published var isWriting = false
    @Published var statusMessage = ""
    
    private var session: NFCNDEFReaderSession?
    
    func writeToNFCTag() {
        guard NFCNDEFReaderSession.readingAvailable else {
            statusMessage = "NFC is not available on this device"
            return
        }
        
        session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        
        session?.alertMessage = "Hold your iPhone near the NFC tag to write"
        isWriting = true
        session?.begin()
    }
}

extension NFCWriter: NFCNDEFReaderSessionDelegate {
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isWriting = false
        }
        
        if let nfcError = error as? NFCReaderError {
            if nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                DispatchQueue.main.async {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Not used in write mode
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag detected")
            return
        }
        
        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }
            
            tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    session.invalidate(errorMessage: "Failed to query tag: \(error!.localizedDescription)")
                    return
                }
                
                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant")
                    
                case .readOnly:
                    session.invalidate(errorMessage: "⚠️ Tag is read-only and cannot be rewritten")
                    
                case .readWrite:
                    self.writeWishMeLuckData(to: tag, session: session)
                    
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }
    
    private func writeWishMeLuckData(to tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        // Create NDEF message with Wish Me Luck identifier
        // Using Text RTD (Record Type Definition) format
        let payloadData = "wishmeLuck".data(using: .utf8)!
        
        // Text Record Format: [Status Byte][Language Code][Text]
        // Status Byte: 0x02 = UTF-8 encoding, language code length = 2
        var textPayload = Data([0x02]) // UTF-8, 2-byte language code
        textPayload.append("en".data(using: .utf8)!) // Language code
        textPayload.append(payloadData) // Actual text
        
        let payload = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: "T".data(using: .utf8)!,
            identifier: Data(),
            payload: textPayload
        )
        
        let message = NFCNDEFMessage(records: [payload])
        
        // CRITICAL: Write WITHOUT locking the tag
        tag.writeNDEF(message) { error in
            if let error = error {
                session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.statusMessage = "❌ Failed to write: \(error.localizedDescription)"
                }
            } else {
                // SUCCESS - Tag is written and remains REWRITABLE
                session.alertMessage = "✅ Successfully wrote Wish Me Luck data!\n\nTag remains rewritable."
                session.invalidate()
                DispatchQueue.main.async {
                    self.statusMessage = "✅ NFC tag successfully programmed!\n\n🔓 Tag is still rewritable - you can update it anytime.\n\nYou can now use this tag to trigger Wish Me Luck."
                }
            }
        }
        
        // NOTE: We deliberately DO NOT call makeLockNDEF()
        // This keeps the tag rewritable for future updates
    }
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("✅ NFC write session active")
    }
}

struct NFCTagWriterView_Previews: PreviewProvider {
    static var previews: some View {
        NFCTagWriterView()
    }
}
