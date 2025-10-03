import SwiftUI
import FirebaseFirestore

struct EventDetailView: View {
    @StateObject var viewModel: EventDetailViewModel
    let event: Event
    @Environment(\.dismiss) var dismiss
    
    init(event: Event) {
        self.event = event
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: event.id ?? ""))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Use the CustomTopBar
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
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Event Image - full width, no padding
                        if let imageUrl = event.metadata?.imageUrl, let url = URL(string: imageUrl) {
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
                        
                        // Content container with padding
                        VStack(alignment: .leading, spacing: 16) {
                            // Event Title
                            Text(event.title ?? event.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.top, 16)
                        
                            // Location and Time
                            HStack(spacing: 12) {
                                if let location = event.location {
                                    Label(location.address, systemImage: "mappin.circle.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
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
                            
                            // Make a Comment Button
                            Button(action: {
                                // Add comment action
                            }) {
                                Text("Make a Comment")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 8)
                            
                            // Rating Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack {
                                        Text(String(format: "%.1f", event.stats?.rating ?? 0.0))
                                            .font(.system(size: 48, weight: .bold))
                                        
                                        HStack(spacing: 4) {
                                            ForEach(0..<5) { index in
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 16))
                                            }
                                        }
                                        
                                        Text("\(event.stats?.totalCompletions ?? 0) reviews")
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
                                                            .fill(Color.orange)
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
                                
                                Text("No comments yet. Be the first!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.bottom, 20)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func getPercentage(for rating: Int) -> Double {
        // Mock data - replace with actual rating distribution from your stats
        let distribution: [Int: Double] = [5: 0.4, 4: 0.3, 3: 0.15, 2: 0.1, 1: 0.05]
        return distribution[rating] ?? 0.0
    }
}
