//
//  ContestBetView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-07-23.
//
import SwiftUI

struct ContestBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    
    var body: some View {
        VStack {
            Text("Contest Bet View")
                .font(.largeTitle)
                .padding()
            Text("Email: \(email)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

