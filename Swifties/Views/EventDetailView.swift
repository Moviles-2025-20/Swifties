import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EventDetailView: View {
    @StateObject var viewModel: EventDetailViewModel
    let event: Event
    @Environment(\.dismiss) var dismiss
    @State private var showAddComment: Bool = false
    @State private var hasAttended: Bool = false
    @State private var isCheckingAttendance: Bool = true
    
    private let db = Firestore.firestore(database: "default")
    
    init(event: Event) {
        self.event = event
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: event.title))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color("appPrimary")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                CustomTopBar(
                    title: "Event Details",
                    showNotificationButton: true,
                    showBackButton: true,
                    onNotificationTap: {
                        // Handle notification tap
                    },
                    onBackTap: {
                        dismiss()
                    }
                )
                
                NavigationLink(isActive: $showAddComment) {
                    AddCommentView(event: event)
                } label: {
                    EmptyView()
                }
                .hidden()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Event Image
                        if !event.metadata.imageUrl.isEmpty, let url = URL(string: event.metadata.imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Event Title
                            Text(event.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.top, 16)
                        
                            // Location and Time
                            HStack(spacing: 12) {
                                Label(event.location?.address ?? "Address not found", systemImage: "mappin.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                if let firstTime = event.schedule.times.first {
                                    Label(firstTime, systemImage: "clock.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Description
                            Text(event.description)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            // Buttons Row
                            HStack(spacing: 12) {
                                // Make a Comment Button
                                Button(action: {
                                    showAddComment = true
                                }) {
                                    Text("Make a Comment")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.appOcher)
                                        .cornerRadius(12)
                                }
                                
                                // Attendance Button
                                Button(action: {
                                    markAsAttending()
                                }) {
                                    HStack {
                                        Image(systemName: hasAttended ? "checkmark.circle.fill" : "hand.raised.fill")
                                        Text(hasAttended ? "Attending!" : "I'm Going")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(hasAttended ? Color.green : Color(.appBlue))
                                    .cornerRadius(12)
                                }
                                .disabled(hasAttended || isCheckingAttendance)
                                .opacity((hasAttended || isCheckingAttendance) ? 0.7 : 1.0)
                            }
                            .padding(.top, 8)
                            
                            // Rating Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack {
                                        Text(String(format: "%.1f", Double(event.stats.rating)))
                                            .font(.system(size: 48, weight: .bold))
                                        
                                        HStack(spacing: 4) {
                                            ForEach(0..<5) { index in
                                                Image(systemName: index < event.stats.rating ? "star.fill" : "star")
                                                    .foregroundColor(.appOcher)
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        
                                        Text("\(event.stats.totalCompletions) reviews")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 6) {
                                        ForEach((1...5).reversed(), id: \.self) { rating in
                                            HStack(spacing: 8) {
                                                Text("\(rating)")
                                                    .font(.caption)
                                                
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.2))
                                                        
                                                        Rectangle()
                                                            .fill(Color.appOcher)
                                                            .frame(width: geo.size.width * getPercentage(for: rating))
                                                    }
                                                }
                                                .frame(height: 8)
                                                .cornerRadius(4)
                                                
                                                Text("\(Int(getPercentage(for: rating) * 100))%")
                                                    .font(.caption)
                                                    .frame(width: 40, alignment: .trailing)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            
                            // Comments Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Comments")
                                    .font(.headline)
                                
                                if viewModel.comments.isEmpty {
                                    Text("No comments yet. Be the first!")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(viewModel.comments.compactMap { $0 }, id: \.id) { comment in
                                        ZStack {
                                            Rectangle()
                                                .fill(Color(.appSecondary))
                                                .cornerRadius(4)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(comment.metadata.title)
                                                    .font(.title3)
                                                    .foregroundColor(.black)
                                                
                                                Text(comment.metadata.text)
                                                    .font(.body)
                                                    .foregroundColor(.black.opacity(0.8))
                                                
                                                HStack {
                                                    if let emotion = comment.emotion {
                                                        Text("🧠 Emotion: \(emotion)")
                                                            .font(.footnote)
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    if let rating = comment.rating {
                                                        Text("Rating: \(rating) Stars")
                                                            .font(.footnote)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                            }
                                            .padding(8)
                                        }
                                        .padding(10)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.bottom, 20)
                            .task {
                                await viewModel.loadComments(event_id: event.id ?? "")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            checkIfUserAttended()
        }
    }
    
    private func getPercentage(for rating: Int) -> Double {
        let distribution: [Int: Double] = [5: 0.4, 4: 0.3, 3: 0.15, 2: 0.1, 1: 0.05]
        return distribution[rating] ?? 0.0
    }
    
    // MARK: - Firebase Methods
    
    private func checkIfUserAttended() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isCheckingAttendance = false
            return
        }
        
        db.collection("user_activities")
            .whereField("user_id", isEqualTo: userId)
            .whereField("event_id", isEqualTo: event.name)
            .whereField("source", isEqualTo: "list_events")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error checking attendance: \(error.localizedDescription)")
                        isCheckingAttendance = false
                        return
                    }
                    
                    let hasAttendedEvent = (snapshot?.documents.count ?? 0) > 0
                    hasAttended = hasAttendedEvent
                    isCheckingAttendance = false
                    
                    print("Attendance check: \(hasAttendedEvent ? "Already attending" : "Not attending yet")")
                }
            }
    }
    
    private func markAsAttending() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            return
        }
        
        let activityData: [String: Any] = [
            "event_id": event.name,
            "source": "list_events",
            "time": Timestamp(date: Date()),
            "time_of_day": getCurrentTimeOfDay(),
            "type": "event_attendance",
            "user_id": userId,
            "with_friends": false
        ]
        
        // Save to UserActivity
        db.collection("user_activities").addDocument(data: activityData) { error in
            if let error = error {
                print("Error saving attendance: \(error.localizedDescription)")
                return
            }
            
            print("Attendance saved successfully!")

            
            AnalyticsService.shared.logCheckIn(activityId: event.id ?? "unknown_event", category: event.category)
            
            // Actualizar evento más reciente del usuario
            self.updateUserLastEvent(userId: userId)
        }
    }
    
    private func updateUserLastEvent(userId: String) {
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "last_event": event.name,
            "last_event_time": Timestamp(date: Date()),
            "event_last_category": event.category
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error updating last_event: \(error.localizedDescription)")
                } else {
                    print("User's last_event updated to: \(self.event.name), category: \(self.event.category)")
                    self.hasAttended = true
                }
            }
        }
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<12:
            return "morning"
        case 12..<17:
            return "afternoon"
        case 17..<21:
            return "evening"
        default:
            return "night"
        }
    }
}
