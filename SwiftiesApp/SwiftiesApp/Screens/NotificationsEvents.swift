//
//  NotificationsEvents.swift
//  SwiftiesApp
//
//  Created by Imac  on 20/09/25.
//

import SwiftUI

struct NotificationsView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack {
                Spacer()
                Text("Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "bell")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color("appBlue")
                .clipShape(
                    .rect(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 30,
                        bottomTrailingRadius: 30,
                        topTrailingRadius: 0
                    )
                )
            )
            
            // Lista de notificaciones
            ScrollView {
                VStack(spacing: 12) {
                    
                    // Notificación normal
                    NotificationCard(
                        avatarImage: "profile",
                        message: "Paolo invited you to an event!\nClick to see all the details."
                    )
                    
                    // Notificación normal
                    NotificationCard(
                        avatarImage: "profile",
                        message: "Paolo has added you as a friend\nPlan your first get together."
                    )
                    
                    // Notificación con imagen de evento
                    NotificationCard(
                        avatarImage: "evento",
                        message: "An event that you may like was added near you! Check it out.",
                        showEventImage: true
                    )
                    
                    // Notificación con imagen de evento diferente
                    NotificationCard(
                        avatarImage: "evento",
                        message: "The event you saved is starting soon! Get there on time.",
                        showEventImage: true
                    )
                    
                    // Otra notificación normal
                    NotificationCard(
                        avatarImage: "profile",
                        message: "Paolo has a free period at noon,\ndo you want to plan an activity?"
                    )
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                
                // Botón de gestionar notificaciones push
                Button(action: {}) {
                    Text("Manage push notifications")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.pink.opacity(0.8))
                        .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 100)
            }
            .background(Color.gray.opacity(0.05))
            
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct NotificationCard: View {
    let avatarImage: String
    let message: String
    var isHighlighted: Bool = false
    var showEventImage: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar o imagen
            if showEventImage {
                Image(avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }
            
            // Mensaje
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            // Borde punteado para notificación destacada
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: isHighlighted ? [8, 4] : []
                    )
                )
                .foregroundColor(isHighlighted ? Color("appBlue") : Color.clear)
        )
        .shadow(
            color: .gray.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

#Preview {
    NotificationsView()
}
