//
//  BaseballView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-25.
//

import Foundation
import SwiftUI

struct BaseballView: View {
    @Binding var navPath: NavigationPath
    @State private var games: [BaseballGame] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastFetchTime: Date? = nil
    @State private var filter: GameFilter = .today
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    let email: String
    let teamToImage: [String: String] = [
        "Arizona Diamondbacks": "DiamondbacksLogo",
        "Atlanta Braves": "BravesLogo",
        "Baltimore Orioles": "OriolesLogo",
        "Boston Red Sox": "RedSoxLogo",
        "Chicago White Sox": "WhiteSoxLogo",
        "Chicago Cubs": "CubsLogo",
        "Cincinnati Reds": "RedsLogo",
        "Cleveland Guardians": "GuardiansLogo",
        "Colorado Rockies": "RockiesLogo",
        "Detroit Tigers": "TigersLogo",
        "Houston Astros": "AstrosLogo",
        "Kansas City Royals": "RoyalsLogo",
        "Los Angeles Angels": "AngelsLogo",
        "Los Angeles Dodgers": "DodgersLogo",
        "Miami Marlins": "MarlinsLogo",
        "Milwaukee Brewers": "BrewersLogo",
        "Minnesota Twins": "TwinsLogo",
        "New York Mets": "MetsLogo",
        "New York Yankees": "YankeesLogo",
        "Athletics": "AthleticsLogo",
        "Philadelphia Phillies": "PhilliesLogo",
        "Pittsburgh Pirates": "PiratesLogo",
        "San Diego Padres": "PadresLogo",
        "San Francisco Giants": "GiantsLogo",
        "Seattle Mariners": "MarinersLogo",
        "St. Louis Cardinals": "CardinalsLogo",
        "Tampa Bay Rays": "RaysLogo",
        "Texas Rangers": "RangersLogo",
        "Toronto Blue Jays": "BlueJaysLogo",
        "Washington Nationals": "NationalsLogo"
    ]

    enum GameFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case next7Days = "Next 7 Days"
        case allUpcoming = "All Upcoming"
        var id: String { rawValue }
    }

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
                    Text("MLB Games")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        fetchMLBGames()
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
                        Image(systemName: "baseball")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No Games Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Check back later for upcoming MLB games")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(filteredGames(), id: \ .id) { game in
                                let gameName = "\(game.home_team_name) vs \(game.away_team_name)"
                                NavigationLink(
                                    value: BetFlowPath.partyLobby(game: game, gameName: gameName, email: email)
                                ) {
                                    VStack(spacing: 0) {
                                        HStack(spacing: 16) {
                                            // Home team
                                            VStack(spacing: 8) {
                                                if let homeImage = teamToImage[game.home_team_name] {
                                                    Image(homeImage)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 60, height: 60)
                                                        .clipShape(Circle())
                                                        .overlay(
                                                            Circle()
                                                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                                        )
                                                }
                                                
                                                Text(game.home_team_name.trimmingCharacters(in: .whitespacesAndNewlines))
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
                                                
                                                Text(formattedDate(from: game.date))
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
                                                if let awayImage = teamToImage[game.away_team_name] {
                                                    Image(awayImage)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 60, height: 60)
                                                        .clipShape(Circle())
                                                        .overlay(
                                                            Circle()
                                                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                                        )
                                                }
                                                
                                                Text(game.away_team_name.trimmingCharacters(in: .whitespacesAndNewlines))
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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: $navPath, email: email)
        }
        .onAppear {
            if games.isEmpty {
                fetchMLBGames()
            }
            Task {
                if let userEmail = sessionManager.userEmail {
                    profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
                }
            }
        }
    }

    func fetchMLBGames() {
        // Only fetch if it has been more than 1 minute since the last fetch
        if let lastFetchTime = lastFetchTime, Date().timeIntervalSince(lastFetchTime) < 60 {
            print("Fetched MLB games recently, skipping API call.")
            return
        }
        
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        var dateQueryItems: [URLQueryItem] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let dateString = formatter.string(from: date)
                dateQueryItems.append(URLQueryItem(name: "dates[]", value: dateString))
            }
        }

        var components = URLComponents(string: "https://api.balldontlie.io/mlb/v1/games")
        components?.queryItems = dateQueryItems

        guard let url = components?.url else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.setValue("5082dadc-9325-464c-b122-f35e59fca4c0", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }

                // DEBUG: Print the raw API response
                print("RAW API RESPONSE: \(String(data: data, encoding: .utf8) ?? "nil")")

                do {
                    let decodedResponse = try JSONDecoder().decode(BaseballResponse.self, from: data)

                    var seen = Set<String>()
                    let uniqueGames = decodedResponse.data.reduce(into: [BaseballGame]()) { result, game in
                        let dateOnly = String(game.date.prefix(10))  
                        let key = "\(game.home_team_name.trimmingCharacters(in: .whitespaces))-" +
                                  "\(game.away_team_name.trimmingCharacters(in: .whitespaces))-" +
                                  "\(dateOnly)"

                        if !seen.contains(key) {
                            result.append(game)
                            seen.insert(key)
                        }
                    }
                    
                    // DEBUG: Print each game's date and parsed date
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    for game in uniqueGames {
                        let parsedDate = isoFormatter.date(from: game.date)
                        print("API date: \(game.date), parsed: \(String(describing: parsedDate))")
                    }
                    // Filter for upcoming games only
                    let now = Date()
                    let upcomingGames = uniqueGames.filter { game in
                        if let gameDate = isoFormatter.date(from: game.date) {
                            return gameDate > now
                        }
                        return false // Exclude if date parsing fails
                    }

                    games = upcomingGames
                    lastFetchTime = Date()
                    
                    print("Fetched \(games.count) unique, upcoming MLB games:")
                    for game in games {
                        print("• \(game.home_team_name) vs \(game.away_team_name) @ \(formattedDate(from: game.date))")
                    }

                } catch {
                    errorMessage = "Failed to decode response: \(error.localizedDescription)"
                }
            }
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
    private func filteredGames() -> [BaseballGame] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let calendar = Calendar.current
        switch filter {
        case .today:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.date) {
                    return calendar.isDate(date, inSameDayAs: now)
                }
                return false
            }
        case .next7Days:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.date) {
                    return date > now && date <= calendar.date(byAdding: .day, value: 7, to: now)!
                }
                return false
            }
        case .allUpcoming:
            return games
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    BaseballView(navPath: .constant(NavigationPath()), email: "123")
        .environment(\.supabaseClient, .development)
}
