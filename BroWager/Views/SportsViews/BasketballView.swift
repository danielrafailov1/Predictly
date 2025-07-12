//
//  BasketballView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI

struct BasketballView: View {
    @Binding var navPath: NavigationPath
    @State private var games: [BasketballGame] = []
    @State private var lastFetchTime: Date? = nil
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    let email: String
    @State private var filter: GameFilter = .today
    enum GameFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case next7Days = "Next 7 Days"
        case allUpcoming = "All Upcoming"
        var id: String { rawValue }
    }
    let teamToPlayer: [String: (playerName: String, imageName: String)] = [
        "Atlanta Hawks": ("Trae Young", "nba-atlanta-hawks-logo-300x300"),
        "Boston Celtics": ("Jayson Tatum", "nba-boston-celtics-logo-300x300"),
        "Brooklyn Nets": ("Kevin Durant", "nba-brooklyn-nets-logo-300x300"),
        "Charlotte Hornets": ("LaMelo Ball", "nba-charlotte-hornets-logo-300x300"),
        "Chicago Bulls": ("Josh Giddey", "nba-chicago-bulls-logo-300x300"),
        "Cleveland Cavaliers": ("Donovan Mitchell", "Clevlan-Cavaliers-logo-2022-300x300"),
        "Dallas Mavericks": ("Luka Doncic", "nba-dallas-mavericks-logo-300x300"),
        "Denver Nuggets": ("Nikola Jokic", "nba-denver-nuggets-logo-300x300"),
        "Detroit Pistons": ("Cade Cunningham", "nba-detroit-pistons-logo-300x300"),
        "Golden State Warriors": ("Stephen Curry", "nba-golden-state-warriors-logo-300x300"),
        "Houston Rockets": ("Alperen Sengun", "nba-houston-rockets-logo-300x300"),
        "Indiana Pacers": ("Tyrese Haliburton", "nba-indiana-pacers-logo-300x300"),
        "Los Angeles Clippers": ("James Harden", "nba-los-angeles-clippers-logo-300x300"),
        "Los Angeles Lakers": ("Luka Doncic", "nba-los-angeles-lakers-logo-300x300"),
        "Memphis Grizzlies": ("Ja Morant", "nba-memphis-grizzlies-logo-300x300"),
        "Miami Heat": ("Tyler Herro", "nba-miami-heat-logo-300x300"),
        "Milwaukee Bucks": ("Giannis Antetokounmpo", "nba-milwaukee-bucks-logo-300x300"),
        "Minnesota Timberwolves": ("Anthony Edwards", "nba-minnesota-timberwolves-logo-300x300"),
        "New Orleans Pelicans": ("Zion Williamson", "nba-new-orleans-pelicans-logo-300x300"),
        "New York Knicks": ("Jalen Brunson", "nba-new-york-knicks-logo-300x300"),
        "Oklahoma City Thunder": ("Shai Gilgeous-Alexander", "nba-oklahoma-city-thunder-logo-300x300"),
        "Orlando Magic": ("Paolo Banchero", "nba-orlando-magic-logo-300x300"),
        "Philadelphia 76ers": ("Joel Embiid", "nba-philadelphia-76ers-logo-300x300"),
        "Phoenix Suns": ("Kevin Durant", "nba-phoenix-suns-logo-300x300"),
        "Portland Trail Blazers": ("Alfernee Simons", "nba-portland-trail-blazers-logo-300x300"),
        "Sacramento Kings": ("Domantas Sabonis", "nba-sacramento-kings-logo-300x300"),
        "San Antonio Spurs": ("Victor Wembanyama", "nba-san-antonio-spurs-logo-300x300"),
        "Toronto Raptors": ("Scottie Barnes", "nba-toronto-raptors-logo-300x300"),
        "Utah Jazz": ("Lauri Markkanen", "nba-utah-jazz-logo-300x300"),
        "Washington Wizards": ("Jordan Poole", "nba-washington-wizards-logo-300x300")
    ]
    
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
                    Text("NBA Games")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await callBasketballAPI()
                        }
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
                
                if games.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "basketball")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No Games Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Check back later for upcoming NBA games")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(filteredGames()) { game in
                                let baseballGame = BaseballGame(id: game.id, home_team_name: game.home_team.full_name, away_team_name: game.visitor_team.full_name, date: game.datetime)
                                gameCard(for: game, baseballGame: baseballGame)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: $navPath, email: email)
        }
        .task {
            await callBasketballAPI()
            if let userEmail = sessionManager.userEmail {
                profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
            }
        }
    }
    
    func callBasketballAPI() async {
        // Only fetch if it has been more than 1 minute since the last fetch
        if let lastFetchTime = lastFetchTime, Date().timeIntervalSince(lastFetchTime) < 60 {
            print("Fetched basketball games recently, skipping API call.")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let today = Date()
        let startDateString = dateFormatter.string(from: today)
        
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        let endDateString = dateFormatter.string(from: endDate)
        
        guard let url = URL(string: "https://api.balldontlie.io/v1/games?start_date=\(startDateString)&end_date=\(endDateString)") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("5082dadc-9325-464c-b122-f35e59fca4c0", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Non-HTTP response")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("API call failed with status: \(httpResponse.statusCode)")
                print(String(data: data, encoding: .utf8) ?? "")
                return
            }
            
            let decoded = try JSONDecoder().decode(GameResponse.self, from: data)
            
            // Filter for upcoming games only
            let now = Date()
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let upcomingGames = decoded.data.filter { game in
                if let gameDate = isoFormatter.date(from: game.datetime) {
                    return gameDate > now
                }
                return false
            }
            
            DispatchQueue.main.async {
                self.games = upcomingGames
                self.lastFetchTime = Date() // Update the timestamp
            }
        } catch {
            print("API error: \(error)")
        }
    }
    
    func formatDate(_ isoDate: String) -> String? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .short
            return outputFormatter.string(from: date)
        }
        return nil
    }
    
    private func gameCard(for game: BasketballGame, baseballGame: BaseballGame) -> some View {
        Button(action: {
            navPath.append(baseballGame)
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Home team
                    VStack(spacing: 8) {
                        if let homePlayer = teamToPlayer[game.home_team.full_name] {
                            Image(homePlayer.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                )
                        }
                        Text(game.home_team.full_name)
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
                        if let gameDate = formatDate(game.datetime) {
                            Text(gameDate)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
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
                        if let visitorPlayer = teamToPlayer[game.visitor_team.full_name] {
                            Image(visitorPlayer.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                )
                        }
                        Text(game.visitor_team.full_name)
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
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // Helper to filter games based on the selected filter
    private func filteredGames() -> [BasketballGame] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let calendar = Calendar.current
        switch filter {
        case .today:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.datetime) {
                    return calendar.isDate(date, inSameDayAs: now)
                }
                return false
            }
        case .next7Days:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.datetime) {
                    return date > now && date <= calendar.date(byAdding: .day, value: 7, to: now)!
                }
                return false
            }
        case .allUpcoming:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.datetime) {
                    return date > now
                }
                return false
            }
        }
    }
}

#Preview {
    BasketballView(navPath: .constant(NavigationPath()), email: "123")
        .environment(\.supabaseClient, .development)
}
