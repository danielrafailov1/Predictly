//
//  SoccerView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI

struct SoccerView: View {
    @State private var games: [SoccerGame] = []
    @State private var teams: [Int: SoccerTeam] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var filter: GameFilter = .today
    
    enum GameFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case next7Days = "Next 7 Days"
        case allUpcoming = "All Upcoming"
        var id: String { rawValue }
    }
    
    let email: String
    
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
                HStack {
                    Text("Premier League")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        fetchSoccerTeamsAndGames()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Filter Picker
                Picker("Filter", selection: $filter) {
                    ForEach(GameFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Error: \(errorMessage)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else if games.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "soccerball")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No Games Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Check back later for upcoming Premier League games")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(filteredGames(), id: \.id) { game in
                                if let home = teams[game.home_team_id],
                                   let away = teams[game.away_team_id] {
                                    VStack(spacing: 0) {
                                        HStack(spacing: 16) {
                                            // Home team
                                            VStack(spacing: 8) {
                                                Text(home.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            .frame(maxWidth: .infinity)
                                            
                                            // VS and time
                                            VStack(spacing: 8) {
                                                Text("VS")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.7))
                                                
                                                Text(formattedDate(from: game.kickoff))
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.6))
                                                
                                                // Betting odds (placeholder)
                                                HStack(spacing: 4) {
                                                    Text("-110")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(.green)
                                                    Text("|")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.3))
                                                    Text("-110")
                                                        .font(.system(size: 12, weight: .semibold))
                                                        .foregroundColor(.green)
                                                }
                                            }
                                            
                                            // Away team
                                            VStack(spacing: 8) {
                                                Text(away.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .padding(16)
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
            }
            .onAppear {
                if games.isEmpty {
                    fetchSoccerTeamsAndGames()
                }
                Task {
                    profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showProfile) {
            // ProfileView removed
        }
    }

    func fetchSoccerTeamsAndGames() {
        isLoading = true
        errorMessage = nil

        guard let teamsURL = URL(string: "https://api.balldontlie.io/epl/v1/teams?season=2024") else {
            errorMessage = "Invalid Teams URL"
            return
        }

        var teamRequest = URLRequest(url: teamsURL)
        teamRequest.setValue("5082dadc-9325-464c-b122-f35e59fca4c0", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: teamRequest) { teamData, _, teamError in
            if let teamError = teamError {
                DispatchQueue.main.async {
                    errorMessage = "Team fetch failed: \(teamError.localizedDescription)"
                    isLoading = false
                }
                return
            }

            guard let teamData = teamData,
                  let decodedTeams = try? JSONDecoder().decode(SoccerTeamResponse.self, from: teamData) else {
                DispatchQueue.main.async {
                    errorMessage = "Failed to decode teams"
                    isLoading = false
                }
                return
            }

            let teamDict = Dictionary(uniqueKeysWithValues: decodedTeams.data.map { ($0.id, $0) })

            guard let gamesURL = URL(string: "https://api.balldontlie.io/epl/v1/games?season=2024") else {
                DispatchQueue.main.async {
                    errorMessage = "Invalid Games URL"
                    isLoading = false
                }
                return
            }

            var gameRequest = URLRequest(url: gamesURL)
            gameRequest.setValue("5082dadc-9325-464c-b122-f35e59fca4c0", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: gameRequest) { gameData, _, gameError in
                DispatchQueue.main.async {
                    isLoading = false

                    if let gameError = gameError {
                        errorMessage = "Game fetch failed: \(gameError.localizedDescription)"
                        return
                    }

                    guard let gameData = gameData else {
                        errorMessage = "No game data received"
                        return
                    }

                    do {
                        let decodedGames = try JSONDecoder().decode(SoccerResponse.self, from: gameData)
                        self.teams = teamDict

                        let now = Date()
                        let isoFormatter = ISO8601DateFormatter()

                        self.games = decodedGames.data.filter { game in
                            if let kickoffDate = isoFormatter.date(from: game.kickoff) {
                                return kickoffDate > now
                            }
                            return false
                        }
                    } catch {
                        errorMessage = "Failed to decode games: \(error.localizedDescription)"
                    }
                }
            }.resume()
        }.resume()
    }

    func formattedDate(from isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .short
            return outputFormatter.string(from: date)
        }
        return isoDate
    }

    // Helper to filter games based on the selected filter
    private func filteredGames() -> [SoccerGame] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let calendar = Calendar.current
        switch filter {
        case .today:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.kickoff) {
                    return calendar.isDate(date, inSameDayAs: now)
                }
                return false
            }
        case .next7Days:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.kickoff) {
                    return date > now && date <= calendar.date(byAdding: .day, value: 7, to: now)!
                }
                return false
            }
        case .allUpcoming:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.kickoff) {
                    return date > now
                }
                return false
            }
        }
    }
}

#Preview {
    SoccerView(email: "123")
        .environment(\.supabaseClient, .development)
}
