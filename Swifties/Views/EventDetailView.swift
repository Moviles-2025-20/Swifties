import SwiftUI

struct EventDetailView: View {
    @StateObject var viewModel: EventDetailViewModel
    let event: Event
    @Environment(\.dismiss) var dismiss
    @State private var showAddComment: Bool = false
    
    init(event: Event) {
        self.event = event
        // Use title as unique identifier since there's no id field
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: event.title))
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color("appPrimary")
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
                
                // Hidden navigation link to push AddCommentView while keeping the Tab Bar visible
                NavigationLink(isActive: $showAddComment) {
                    AddCommentView(event: event)
                } label: {
                    EmptyView()
                }
                .hidden()
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Event Image - full width, no padding
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
                        
                        // Content container with padding
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
                            
                            // Make a Comment Button
                            Button(action: {
                                showAddComment = true
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
                                        Text(String(format: "%.1f", Double(event.stats.rating)))
                                            .font(.system(size: 48, weight: .bold))
                                        
                                        HStack(spacing: 4) {
                                            ForEach(0..<5) { index in
                                                Image(systemName: index < event.stats.rating ? "star.fill" : "star")
                                                    .foregroundColor(.orange)
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
    }
    
    private func getPercentage(for rating: Int) -> Double {
        // Mock data - replace with actual rating distribution from your stats
        let distribution: [Int: Double] = [5: 0.4, 4: 0.3, 3: 0.15, 2: 0.1, 1: 0.05]
        return distribution[rating] ?? 0.0
    }
}

