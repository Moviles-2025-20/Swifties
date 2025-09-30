//
//  EventInfo.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/09/25.
//

import SwiftUI

/// A reusable event pod/card with image, colored title, description, time and walking distance.
/// - **Parameters**:
///   - imagePath: Local asset name or file path for the event photo.
///   - title: Event title text.
///   - titleColor: Background color for the title area (configurable externally).
///   - description: Short description of the event.
///   - timeText: A formatted time string (e.g., "Today, 5:30 PM").
///   - walkingMinutes: Walking distance in minutes.

struct EventInfo: View {
    let imagePath: String
    let title: String
    let titleColor: Color
    let description: String
    let timeText: String
    let walkingMinutes: Int
    let location: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left image
            eventImage
                .resizable()
                .scaledToFill()
                .frame(width: 75, height: 100)
                .clipped()
                .cornerRadius(10)

            // Right content
            VStack(alignment: .leading, spacing: 8) {
                // Title chip with configurable background color
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(titleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .lineLimit(1)

                // Description
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Meta info rows
                VStack(alignment: .leading, spacing: 4) {
                    // First row: Time and walking distance
                    HStack(spacing: 12) {
                        // Time with icon
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .imageScale(.small)
                            Text(timeText)
                                .lineLimit(1)
                                .font(Font.caption.bold())
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        // Walking distance with icon
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .imageScale(.small)
                            Text("\(walkingMinutes) min")
                                .font(Font.caption.bold())
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                     
                        // Second row: Location (if provided)
                        if let location = location {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .imageScale(.small)
                                Text(location)
                                    .lineLimit(1)
                                    .font(Font.caption.bold())
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Image loader helper
    private var eventImage: Image {
        // Try to load from asset catalog first, then from file path URL
        if let uiImage = UIImage(named: imagePath) {
            return Image(uiImage: uiImage)
        } else if let image = UIImage(contentsOfFile: imagePath) {
            return Image(uiImage: image)
        } else {
            // Fallback placeholder
            return Image(systemName: "photo")
        }
    }
}
