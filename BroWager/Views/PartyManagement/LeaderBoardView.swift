//
//  LeaderBoardView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI
import Supabase

struct LeaderBoardView: View {
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Leaderboard")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("See who's leading the competition")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 32)
                
                // Placeholder for future content
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No rankings yet")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Place your first bet to join the competition")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            Task {
                if let userEmail = sessionManager.userEmail {
                    profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
                }
            }
        }
    }
}

#Preview {
    LeaderBoardView()
        .environment(\.supabaseClient, .development)
}
