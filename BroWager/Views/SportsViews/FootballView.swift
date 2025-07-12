//
//  FootballView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI

struct FootballView: View {
    @State private var games: [NFLGame] = []
    @State private var errorMessage: String? = nil
    @State private var selectedGame: NFLGame? = nil
    @State private var isShowingGameDetail = false
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var lastFetchTime: Date? = nil
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    @State private var filter: GameFilter = .today

    enum GameFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case next7Days = "Next 7 Days"
        case allUpcoming = "All Upcoming"
        var id: String { rawValue }
    }

    let email: String
    let teamToPlayer: [String: (playerName: String, imageName: String)] = [
       // AFC East
       "Buffalo Bills": ("Josh Allen", "JoshAllen"),
       "Miami Dolphins": ("Tyreek Hill", "TyreekHill"),
       "New England Patriots": ("Matthew Judon", "MatthewJudon"),
       "New York Jets": ("Sauce Gardner", "SauceGardner"),
       // AFC North
       "Baltimore Ravens": ("Lamar Jackson", "LamarJackson"),
       "Cincinnati Bengals": ("Joe Burrow", "JoeBurrow"),
       "Cleveland Browns": ("Myles Garrett", "MylesGarrett"),
       "Pittsburgh Steelers": ("T.J. Watt", "TJWatt"),
       // AFC South
       "Houston Texans": ("C.J. Stroud", "CJStroud"),
       "Indianapolis Colts": ("Jonathan Taylor", "JonathanTaylor"),
       "Jacksonville Jaguars": ("Trevor Lawrence", "TrevorLawrence"),
       "Tennessee Titans": ("Derrick Henry", "DerrickHenry"),
       // AFC West
       "Denver Broncos": ("Patrick Surtain II", "PatrickSurtain"),
       "Kansas City Chiefs": ("Patrick Mahomes", "PatrickMahomes"),
       "Las Vegas Raiders": ("Davante Adams", "DavanteAdams"),
       "Los Angeles Chargers": ("Justin Herbert", "JustinHerbert"),
       // NFC East
       "Dallas Cowboys": ("Micah Parsons", "MicahParsons"),
       "New York Giants": ("Saquon Barkley", "SaquonBarkley"),
       "Philadelphia Eagles": ("Jalen Hurts", "JalenHurts"),
       "Washington Commanders": ("Terry McLaurin", "TerryMcLaurin"),
       // NFC North
       "Chicago Bears": ("D.J. Moore", "DJMoore"),
       "Detroit Lions": ("Amon-Ra St. Brown", "AmonRaStBrown"),
       "Green Bay Packers": ("Jordan Love", "JordanLove"),
       "Minnesota Vikings": ("Justin Jefferson", "JustinJefferson"),
       // NFC South
       "Atlanta Falcons": ("Bijan Robinson", "BijanRobinson"),
       "Carolina Panthers": ("Brian Burns", "BrianBurns"),
       "New Orleans Saints": ("Alvin Kamara", "AlvinKamara"),
       "Tampa Bay Buccaneers": ("Mike Evans", "MikeEvans"),
       // NFC West
       "Arizona Cardinals": ("Kyler Murray", "KylerMurray"),
       "Los Angeles Rams": ("Aaron Donald", "AaronDonald"),
       "San Francisco 49ers": ("Christian McCaffrey", "ChristianMcCaffrey"),
       "Seattle Seahawks": ("D.K. Metcalf", "DKMetcalf")
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
                    Text("NFL Games")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        Task {
                            await refreshGames()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                // Filter Picker
                Picker("Filter", selection: $filter) {
                    ForEach(GameFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)

                if isLoading && games.isEmpty {
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
                        Image(systemName: "football")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("No Games Available")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Check back later for upcoming NFL games")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        RefreshableView(action: {
                            await refreshGames()
                        }) {
                            VStack(spacing: 16) {
                                ForEach(filteredGames(), id: \ .id) { game in
                                    GameCard(game: game, teamToPlayer: teamToPlayer)
                                        .onTapGesture {
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                            selectedGame = game
                                            isShowingGameDetail = true
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $isShowingGameDetail) {
            if let game = selectedGame {
                GameDetailView(game: game, teamToPlayer: teamToPlayer)
            }
        }
        .task {
            await callFootballAPI()
        }
    }

    private func refreshGames() async {
        isRefreshing = true
        await callFootballAPI()
        isRefreshing = false
    }

    private func callFootballAPI() async {
        // Only fetch if it has been more than 1 minute since the last fetch
        if let lastFetchTime = lastFetchTime, Date().timeIntervalSince(lastFetchTime) < 60, !isRefreshing {
            print("Fetched NFL games recently, skipping API call.")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let today = Date()
        let calendar = Calendar.current

        let dateQueryParams = (0..<7).map { offset -> String in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let formatted = dateFormatter.string(from: date)
            return "dates[]=\(formatted)"
        }.joined(separator: "&")

        let baseURL = "https://api.balldontlie.io/nfl/v1/games"
        let fullURLString = "\(baseURL)?\(dateQueryParams)"

        guard let url = URL(string: fullURLString) else {
            DispatchQueue.main.async {
                self.games = []
                self.errorMessage = nil
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("5082dadc-9325-464c-b122-f35e59fca4c0", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.games = []
                    self.errorMessage = nil
                }
                return
            }

            let jsonString = String(data: data, encoding: .utf8)
            print("NFL JSON Response: \(jsonString ?? "nil")")

            do {
                let decoded = try JSONDecoder().decode(NFLResponse.self, from: data)
                DispatchQueue.main.async {
                    self.games = decoded.data
                    self.errorMessage = nil
                    self.lastFetchTime = Date()
                }
            } catch {
                DispatchQueue.main.async {
                    self.games = []
                    self.errorMessage = nil
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.games = []
                self.errorMessage = nil
            }
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

    // Helper to filter games based on the selected filter
    private func filteredGames() -> [NFLGame] {
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
            return games.filter { game in
                if let date = isoFormatter.date(from: game.date) {
                    return date > now
                }
                return false
            }
        }
    }
}

struct NFLResponse: Codable {
    let data: [NFLGame]
    let meta: Meta
}

struct Meta: Codable {
    let per_page: Int
    let next_cursor: Int
}

struct NFLGame: Codable, Identifiable {
    let id: Int
    let summary: String
    let venue: String
    let week: Int
    let date: String
    let season: Int
    let postseason: Bool
    let status: String

    let home_team: NFLTeam
    let visitor_team: NFLTeam

    let home_team_score: Int
    let visitor_team_score: Int
}

struct NFLTeam: Codable {
    let id: Int
    let conference: String
    let division: String
    let location: String
    let name: String
    let full_name: String
    let abbreviation: String
}

struct GameCard: View {
    let game: NFLGame
    let teamToPlayer: [String: (playerName: String, imageName: String)]
    
    var body: some View {
        VStack(spacing: 0) {
            // Card content
            HStack(spacing: 16) {
                // Home team
                TeamView(
                    team: game.home_team,
                    player: teamToPlayer[game.home_team.full_name],
                    isHome: true
                )
                
                // VS and time
                VStack(spacing: 8) {
                    Text("VS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if let gameDate = formatDate(game.date) {
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
                TeamView(
                    team: game.visitor_team,
                    player: teamToPlayer[game.visitor_team.full_name],
                    isHome: false
                )
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
    
    private func formatDate(_ isoDate: String) -> String? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .none
            outputFormatter.timeStyle = .short
            return outputFormatter.string(from: date)
        }
        return nil
    }
}

struct TeamView: View {
    let team: NFLTeam
    let player: (playerName: String, imageName: String)?
    let isHome: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            if let player = player {
                Image(player.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
            }
            
            Text(team.full_name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GameDetailView: View {
    let game: NFLGame
    let teamToPlayer: [String: (playerName: String, imageName: String)]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Teams and score
                    HStack(spacing: 32) {
                        TeamDetailView(
                            team: game.home_team,
                            player: teamToPlayer[game.home_team.full_name],
                            score: game.home_team_score
                        )
                        
                        Text("VS")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.7))
                        
                        TeamDetailView(
                            team: game.visitor_team,
                            player: teamToPlayer[game.visitor_team.full_name],
                            score: game.visitor_team_score
                        )
                    }
                    .padding(.top, 32)
                    
                    // Game info
                    VStack(spacing: 16) {
                        GameDetailInfoRow(title: "Venue", value: game.venue)
                        GameDetailInfoRow(title: "Week", value: "Week \(game.week)")
                        GameDetailInfoRow(title: "Status", value: game.status)
                        if let date = formatDate(game.date) {
                            GameDetailInfoRow(title: "Date", value: date)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Betting options
                    VStack(spacing: 16) {
                        Text("Betting Options")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        BettingOptionRow(title: "Money Line", homeOdds: "-110", awayOdds: "-110")
                        BettingOptionRow(title: "Spread", homeOdds: "-2.5 (-110)", awayOdds: "+2.5 (-110)")
                        BettingOptionRow(title: "Over/Under", homeOdds: "O 48.5 (-110)", awayOdds: "U 48.5 (-110)")
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    private func formatDate(_ isoDate: String) -> String? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .medium
            outputFormatter.timeStyle = .short
            return outputFormatter.string(from: date)
        }
        return nil
    }
}

struct TeamDetailView: View {
    let team: NFLTeam
    let player: (playerName: String, imageName: String)?
    let score: Int
    
    var body: some View {
        VStack(spacing: 12) {
            if let player = player {
                Image(player.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
            }
            
            Text(team.full_name)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("\(score)")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct GameDetailInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
}

struct BettingOptionRow: View {
    let title: String
    let homeOdds: String
    let awayOdds: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 16) {
                Text(homeOdds)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                Text(awayOdds)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

struct RefreshableView<Content: View>: View {
    let action: () async -> Void
    let content: Content
    
    @State private var isRefreshing = false
    @State private var refreshOffset: CGFloat = 0
    
    init(action: @escaping () async -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .top) {
                    MovingView(action: action, isRefreshing: $isRefreshing, refreshOffset: $refreshOffset)
                        .offset(y: -50)
                    
                    VStack {
                        content
                    }
                    .offset(y: isRefreshing ? 50 : 0)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                if value > 50 && !isRefreshing {
                    isRefreshing = true
                    Task {
                        await action()
                        withAnimation {
                            isRefreshing = false
                        }
                    }
                }
                refreshOffset = value
            }
        }
    }
}

struct MovingView: View {
    let action: () async -> Void
    @Binding var isRefreshing: Bool
    @Binding var refreshOffset: CGFloat
    
    var body: some View {
        HStack {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(refreshOffset > 50 ? 180 : 0))
            }
            Text(isRefreshing ? "Refreshing..." : "Pull to refresh")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(height: 50)
        .opacity(refreshOffset > 0 ? min(refreshOffset / 50, 1) : 0)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    FootballView(email: "123")
        .environment(\.supabaseClient, .development)
}
