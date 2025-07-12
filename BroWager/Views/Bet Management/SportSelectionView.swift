//
//  CreatedBetView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI

struct SportSelectionView: View {
    @Binding var navPath: NavigationPath
    let email: String
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    
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
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Create New Bet")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Choose a sport to bet on")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                // Sports Grid
                ScrollView {
                    VStack(spacing: 16) {
                        // Basketball
                        NavigationLink(value: Sport.basketball) {
                            sportButtonContent(
                                title: "Basketball",
                                icon: "basketball.fill",
                                color: .orange
                            )
                        }
                        
                        // Hockey
                        NavigationLink(value: Sport.hockey) {
                            sportButtonContent(
                                title: "Hockey",
                                icon: "hockey.puck.fill",
                                color: .red
                            )
                        }
                        
                        // Football
                        NavigationLink(value: Sport.football) {
                            sportButtonContent(
                                title: "Football",
                                icon: "football.fill",
                                color: .green
                            )
                        }
                        
                        // Soccer
                        NavigationLink(value: Sport.soccer) {
                            sportButtonContent(
                                title: "Soccer",
                                icon: "soccerball",
                                color: .blue
                            )
                        }
                        
                        // Baseball
                        NavigationLink(value: Sport.baseball) {
                            sportButtonContent(
                                title: "Baseball",
                                icon: "baseball.fill",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationDestination(for: Sport.self) { sport in
                switch sport {
                case .basketball:
                    BasketballView(navPath: $navPath, email: email)
                case .hockey:
                    HockeyView(email: email)
                case .football:
                    FootballView(email: email)
                case .soccer:
                    SoccerView(email: email)
                case .baseball:
                    BaseballView(navPath: $navPath, email: email)
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: $navPath, email: email)
        }
        .onAppear {
            Task {
                profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
            }
        }
        .navigationDestination(for: BetFlowPath.self) { path in
            switch path {
            case .partyLobby(let game, let gameName, let email):
                PartyLobbyView(navPath: $navPath, game: game, gameName: gameName, email: email)
            case .createParty(let partyCode, let betType, let userEmail):
                CreatePartyView(navPath: $navPath, partyCode: partyCode, betType: betType, userEmail: userEmail)
            case .gameEvent(let game, let partyId, let userId, let betType, let partyCode, let userEmail):
                GameEventHostView(navPath: $navPath, game: game, partyId: partyId, userId: userId, betType: betType, refreshCount: .constant(0), maxRefreshes: 3, partyCode: partyCode, userEmail: userEmail, fixedEvents: nil)
            case .partyDetails(let partyCode, let email):
                PartyDetailsView(partyCode: partyCode, email: email)
            }
        }
    }
    
    @ViewBuilder
    private func sportButtonContent(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 20) {
            // Sport Icon
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color,
                            color.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Sport Name
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SportSelectionView(navPath: .constant(NavigationPath()), email: "daniel123@gmail.com")
        .environment(\.supabaseClient, .development)
}
