//
//  DetailEvent.swift
//  SwiftiesApp
//
//  Created by Imac  on 19/09/25.
//

import SwiftUI

struct DetailEvent: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color("appPrimary")
                .ignoresSafeArea()
            
            VStack {
                CustomTopBar(title: "Hi, Juliana!", showNotificationButton: true) {
                    print("Notifications tapped")
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Barra de búsqueda
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.black)
                            Text("Search…")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // Map view y filtros
                        HStack {
                            // Botón Filter
                            Button(action: {}) {
                                HStack(spacing: 6) {
                                    Text("Filter")
                                        .font(.subheadline)
                                        .foregroundColor(.black)
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .foregroundColor(.black)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            // Map view con toggle
                            HStack(spacing: 8) {
                                Text("Map view")
                                    .foregroundColor(.black)
                                    .font(.subheadline)
                                
                                Toggle("", isOn: .constant(false))
                                    .toggleStyle(SwitchToggleStyle(tint: Color("appBlue")))
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Tarjeta del evento
                        VStack(alignment: .leading, spacing: 8) {
                            Image("detail_image")
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Text("Food Fest")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color("appOcher"))
                                                .foregroundColor(.white)
                                                .clipShape(Capsule())
                                            Spacer()
                                        }
                                        .padding(8)
                                    }
                                )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.gray)
                                    Text("El bobo")
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.gray)
                                    Text("Today, 6:00 pm")
                                        .font(.subheadline)
                                }
                                
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .foregroundColor(.gray)
                                    Text("2 min")
                                        .font(.subheadline)
                                }
                                
                                Text("In Centro de Japón, there is an Asian food festival where you can try typical dishes from different countries, sharing flavors and traditions in one place.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .gray.opacity(0.2), radius: 6, x: 0, y: 4)
                        .padding(.horizontal)
                        
                        // Rating
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("4.5")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                VStack(alignment: .leading) {
                                    HStack(spacing: 2) {
                                        ForEach(0..<5) { index in
                                            Image(systemName: index < 4 ? "star.fill" : "star")
                                                .foregroundColor(Color("appOcher"))
                                        }
                                    }
                                    Text("125 reviews")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Barras de calificación
                            VStack(alignment: .leading, spacing: 6) {
                                RatingRow(stars: 5, percent: 40, color: Color("appOcher"))
                                RatingRow(stars: 4, percent: 30, color: Color("appOcher"))
                                RatingRow(stars: 3, percent: 15, color: Color("appOcher"))
                                RatingRow(stars: 2, percent: 10, color: Color("appOcher"))
                                RatingRow(stars: 1, percent: 5, color: Color("appOcher"))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Sección de comentarios - SIMPLE
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Comments")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            // Un solo comentario
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("@maria_foodie")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        HStack(spacing: 2) {
                                            ForEach(0..<5) { _ in
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(Color("appOcher"))
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                    
                                    Text("Amazing variety of Asian cuisines! The ramen booth was my favorite.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                }
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

// Subvista para cada fila de rating
struct RatingRow: View {
    var stars: Int
    var percent: Int
    var color: Color
    
    var body: some View {
        HStack {
            Text("\(stars)")
                .font(.footnote)
            ProgressView(value: Float(percent), total: 100)
                .accentColor(color)
            Text("\(percent)%")
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    DetailEvent()
}
