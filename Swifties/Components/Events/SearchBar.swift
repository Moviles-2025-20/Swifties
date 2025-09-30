//
//  SearchBar.swift
//  Swifties
//
//  Created by Natalia Villegas Calderón on 28/09/25.
//

import SwiftUI

struct SearchBar: View {
    @Binding var searchText: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 12)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 12)
        }
        .background(Color.white)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 16)
    }
}
