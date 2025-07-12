//
//  HockeyView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI

struct HockeyView: View {
    @State private var games: [NHLGame] = []
    let email: String
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
    let teamToPlayer: [String: (playerName: String, imageName: String)] = [
        "Anaheim Ducks": ("Trevor Zegras", "TrevorZegras"),
        "Arizona Coyotes": ("Clayton Keller", "ClaytonKeller"),
        "Boston Bruins": ("David Pastrnak", "DavidPastrnak"),
        "Buffalo Sabres": ("Rasmus Dahlin", "RasmusDahlin"),
        "Calgary Flames": ("Jonathan Huberdeau", "JonathanHuberdeau"),
        "Carolina Hurricanes": ("Sebastian Aho", "SebastianAho"),
        "Chicago Blackhawks": ("Connor Bedard", "ConnorBedard"),
        "Colorado Avalanche": ("Nathan MacKinnon", "NathanMacKinnon"),
        "Columbus Blue Jackets": ("Johnny Gaudreau", "JohnnyGaudreau"),
        "Dallas Stars": ("Jason Robertson", "JasonRobertson"),
        "Detroit Red Wings": ("Dylan Larkin", "DylanLarkin"),
        "Edmonton Oilers": ("Connor McDavid", "ConnorMcDavid"),
        "Florida Panthers": ("Aleksander Barkov", "AleksanderBarkov"),
        "Los Angeles Kings": ("Anze Kopitar", "AnzeKopitar"),
        "Minnesota Wild": ("Kirill Kaprizov", "KirillKaprizov"),
        "Montreal Canadiens": ("Cole Caufield", "ColeCaufield"),
        "Nashville Predators": ("Filip Forsberg", "FilipForsberg"),
        "New Jersey Devils": ("Jack Hughes", "JackHughes"),
        "New York Islanders": ("Mathew Barzal", "MathewBarzal"),
        "New York Rangers": ("Artemi Panarin", "ArtemiPanarin"),
        "Ottawa Senators": ("Tim Stützle", "TimStutzle"),
        "Philadelphia Flyers": ("Travis Konecny", "TravisKonecny"),
        "Pittsburgh Penguins": ("Sidney Crosby", "SidneyCrosby"),
        "San Jose Sharks": ("Tomas Hertl", "TomasHertl"),
        "Seattle Kraken": ("Matty Beniers", "MattyBeniers"),
        "St. Louis Blues": ("Jordan Kyrou", "JordanKyrou"),
        "Tampa Bay Lightning": ("Nikita Kucherov", "NikitaKucherov"),
        "Toronto Maple Leafs": ("Auston Matthews", "AustonMatthews"),
        "Vancouver Canucks": ("Elias Pettersson", "EliasPettersson"),
        "Vegas Golden Knights": ("Jack Eichel", "JackEichel"),
        "Washington Capitals": ("Alex Ovechkin", "AlexOvechkin"),
        "Winnipeg Jets": ("Kyle Connor", "KyleConnor")
    ]

    var body: some View {
        ZStack {
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
                HStack {
                    Text("NHL Games")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await fetchHockeyGames()
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
                        Image(systemName: "hockey.puck")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No Games Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Check back later for upcoming NHL games")
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
                                VStack(spacing: 0) {
                                    HStack(spacing: 16) {
                                        VStack(spacing: 8) {
                                            if let homePlayer = teamToPlayer[game.homeTeam] {
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
                                            
                                            Text(game.homeTeam)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.8)
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        VStack(spacing: 8) {
                                            Text("VS")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white.opacity(0.7))
                                            
                                            if let gameDate = formatDate(game.dateTime) {
                                                Text(gameDate)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                            
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
                                        
                                        VStack(spacing: 8) {
                                            if let awayPlayer = teamToPlayer[game.awayTeam] {
                                                Image(awayPlayer.imageName)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(Circle())
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                                    )
                                            }
                                            
                                            Text(game.awayTeam)
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
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
            }
            .task {
                await fetchHockeyGames()
                profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: .constant(NavigationPath()), email: email)
        }
    }

    func fetchHockeyGames() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        guard let url = URL(string: "https://api-web.nhle.com/v1/schedule/now") else {
            print("Invalid NHL API URL")
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(NHLScheduleResponse.self, from: data)

            let allGames = decoded.dates.flatMap { $0.games }.map {
                NHLGame(
                    id: $0.gamePk,
                    homeTeam: $0.teams.home.team.name,
                    awayTeam: $0.teams.away.team.name,
                    dateTime: $0.gameDate
                )
            }

            DispatchQueue.main.async {
                self.games = allGames
            }

        } catch {
            print("Failed to fetch NHL games: \(error)")
        }
    }

    func formatDate(_ isoDate: String) -> String? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .short
            return outputFormatter.string(from: date)
        }
        return nil
    }

    private func filteredGames() -> [NHLGame] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let calendar = Calendar.current
        switch filter {
        case .today:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.dateTime) {
                    return calendar.isDate(date, inSameDayAs: now)
                }
                return false
            }
        case .next7Days:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.dateTime) {
                    return date > now && date <= calendar.date(byAdding: .day, value: 7, to: now)!
                }
                return false
            }
        case .allUpcoming:
            return games.filter { game in
                if let date = isoFormatter.date(from: game.dateTime) {
                    return date > now
                }
                return false
            }
        }
    }
}

#Preview {
    HockeyView(email: "123")
}
