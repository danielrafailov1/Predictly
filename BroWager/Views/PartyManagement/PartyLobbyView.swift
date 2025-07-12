//
//  PartyLobbyView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-06.
//

import Foundation
import SwiftUI
import Supabase

// Move these to PartyModels.swift
struct PartyResponse: Codable {
    let id: Int
}

struct UserResponse: Codable {
    let user_id: String
}

struct PartyLobbyView: View {
    @Binding var navPath: NavigationPath
    let game: BaseballGame
    let gameName: String
    let email: String

    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedBetType: BetType = .predefined
    @State private var betDetails: BetDetails = BetDetails()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var createdPartyCode: String = ""
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @State private var showGameEventView = false
    @State private var pendingPartySettings: PartySettings? = nil
    @State private var generatedEvents: [String] = []
    @State private var tutorialBetType: BetType? = nil

    struct BetDetails {
        var partyName: String = ""
        var privacyOption: PrivacyOption = .open
        var maxMembers: Int = 6
        var betAmount: String = ""
        // Modular bet details
        var predefinedOption: String = ""
        var draftTeam: [String] = []
        var randomPlayer: String = ""
        var stat: String = ""
        var outcome: String = ""
        var customOutcome: String = ""
        var deadline: Date = Date()
    }

    struct PartySettings: Identifiable {
        let id = UUID()
        var name: String
        var privacy: PrivacyOption
        var maxMembers: Int
        var betQuantity: Int
        var betType: BetType
        var game: BaseballGame
    }

    enum PrivacyOption: String, CaseIterable, Identifiable {
        case friendsOnly = "Friends Only"
        case open = "Open"
        case inviteOnly = "Invite Only"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Color.green.opacity(0.05) // Diagnostic: background color to see if ZStack loads
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .onAppear { print("PartyLobbyView: isLoading = true") }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .onAppear { print("PartyLobbyView: errorMessage = \(error)") }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        Text("Create a Party & Bet")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.top, 16)

                        // Game Info Card
                        VStack(spacing: 12) {
                            Text(gameName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text(formattedDate(from: game.date))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)

                        // Party Name & Settings
                        VStack(spacing: 20) {
                            // Party Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Party Name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                HStack(spacing: 12) {
                                    TextField("Enter party name", text: $betDetails.partyName)
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    Button(action: generateRandomName) {
                                        Image(systemName: "dice.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Privacy Option
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Privacy")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Picker("Privacy", selection: $betDetails.privacyOption) {
                                    ForEach(PrivacyOption.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            .padding(.horizontal)

                            // Max Members
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Maximum Members")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                Stepper("\(betDetails.maxMembers) members", value: $betDetails.maxMembers, in: 2...10)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)

                            // Bet Amount
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bet Amount (tokens)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                TextField("Enter bet amount", text: $betDetails.betAmount)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .keyboardType(.numberPad)
                                    .submitLabel(.done)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .onChange(of: betDetails.betAmount) { newValue in
                                        // Only allow numbers and limit to 500
                                        let filtered = newValue.filter { "0123456789".contains($0) }
                                        if let intValue = Int(filtered), intValue > 500 {
                                            betDetails.betAmount = "500"
                                        } else {
                                            betDetails.betAmount = filtered
                                        }
                                    }
                            }
                            .padding(.horizontal)
                        }

                        // Bet Type Segmented Control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bet Type")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            VStack(spacing: 16) {
                                ForEach(BetType.allCases) { type in
                                    PartyBetTypeCard(
                                        betType: type,
                                        isSelected: selectedBetType == type,
                                        showTutorial: { tutorialBetType = type },
                                        select: { selectedBetType = type }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Dynamic Bet Type Form
                        Group {
                            switch selectedBetType {
                            case .predefined:
                                EmptyView() // No dropdown or extra UI for predefined
                            case .draftTeam:
                                DraftTeamBetForm(betDetails: $betDetails)
                            case .randomPlayer:
                                RandomPlayerBetForm(betDetails: $betDetails)
                            case .statBased:
                                StatBasedBetForm(betDetails: $betDetails)
                            case .outcomeBased:
                                OutcomeBasedBetForm(betDetails: $betDetails)
                            case .custom:
                                CustomBetForm(betDetails: $betDetails)
                            case .politics:
                                EmptyView() // Placeholder for future politics bet form
                            case .food:
                                EmptyView() // Placeholder for future food bet form
                            case .lifeEvents:
                                EmptyView() // Placeholder for future life events bet form
                            }
                        }
                        .padding(.horizontal)

                        // Create Party Button
                        Button(action: {
                            pendingPartySettings = PartySettings(
                                name: betDetails.partyName,
                                privacy: betDetails.privacyOption,
                                maxMembers: betDetails.maxMembers,
                                betQuantity: Int(betDetails.betAmount) ?? 0,
                                betType: selectedBetType,
                                game: game
                            )
                            print("[PartyLobbyView] Setting pendingPartySettings to: \(String(describing: pendingPartySettings))")
                        }) {
                            Text("Generate Bets")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background((!betDetails.partyName.isEmpty && !betDetails.betAmount.isEmpty) ? Color.green : Color.gray)
                                .cornerRadius(16)
                                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(betDetails.partyName.isEmpty || betDetails.betAmount.isEmpty)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }
                }
                .padding(.vertical)
                .onAppear { print("PartyLobbyView: loaded, gameName = \(gameName)") }
            }
        }
        .navigationDestination(isPresented: $showProfile) {
            ProfileView(navPath: .constant(NavigationPath()), email: email)
        }
        .onAppear {
            print("PartyLobbyView: onAppear called")
            Task {
                profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
            }
        }
        .sheet(item: $pendingPartySettings) { settings in
            GameEventView(
                partySettings: (
                    name: settings.name,
                    privacy: settings.privacy,
                    maxMembers: settings.maxMembers,
                    betQuantity: settings.betQuantity,
                    betType: settings.betType,
                    game: settings.game
                ),
                onPartyCreated: { partyCode in
                    navPath.append(BetFlowPath.partyDetails(partyCode: partyCode, email: email))
                    pendingPartySettings = nil // Dismiss sheet after party creation
                },
                fixedEvents: nil,
                partyId: nil,
                userId: email,
                previousBet: nil // No previous bet for party creation
            )
            .onAppear {
                print("[PartyLobbyView] .sheet content evaluated. pendingPartySettings: \(String(describing: pendingPartySettings))")
            }
        }
        .sheet(item: $tutorialBetType) { betType in
            VStack(spacing: 24) {
                Image(systemName: betType.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                    .padding(.top, 32)
                Text(betType.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                Text(betType.detailedDescription)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
                Button("Got it!") { tutorialBetType = nil }
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 48)
                    .background(Color.blue)
                    .cornerRadius(14)
                    .padding(.bottom, 32)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func generateRandomName() {
        let adjectives = ["Epic", "Legendary", "Awesome", "Super", "Mega", "Ultra", "Pro", "Elite", "Prime", "Royal"]
        let nouns = ["Party", "Squad", "Team", "Crew", "Gang", "Club", "League", "Alliance", "Union", "Federation"]
        let randomAdjective = adjectives.randomElement() ?? "Epic"
        let randomNoun = nouns.randomElement() ?? "Party"
        betDetails.partyName = "\(randomAdjective)\(randomNoun)"
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
}

// MARK: - Modular Bet Type Forms

struct DraftTeamBetForm: View {
    @Binding var betDetails: PartyLobbyView.BetDetails
    var body: some View {
        EmptyView()
    }
}

struct RandomPlayerBetForm: View {
    @Binding var betDetails: PartyLobbyView.BetDetails
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Random player bet (future feature)")
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct StatBasedBetForm: View {
    @Binding var betDetails: PartyLobbyView.BetDetails
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stat-based bet (future feature)")
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct OutcomeBasedBetForm: View {
    @Binding var betDetails: PartyLobbyView.BetDetails
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outcome-based bet (future feature)")
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct CustomBetForm: View {
    @Binding var betDetails: PartyLobbyView.BetDetails
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Describe your custom bet:")
                .foregroundColor(.white)
            TextField("Custom outcome", text: $betDetails.customOutcome)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// Add/Update PartyBetTypeCard and BetType extension:
struct PartyBetTypeCard: View {
    let betType: BetType
    var isSelected: Bool
    var showTutorial: () -> Void = {}
    var select: () -> Void = {}
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(systemName: betType.icon)
                .font(.system(size: 32))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue,
                            Color.blue.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(betType.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: showTutorial) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
                Text(betType.shortDescription)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isSelected ? Color.blue.opacity(0.18) : Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.13), lineWidth: 2)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .onTapGesture { select() }
    }
}

extension BetType {
    var icon: String {
        switch self {
        case .predefined: return "list.bullet.rectangle.portrait"
        case .draftTeam: return "person.3.sequence.fill"
        case .randomPlayer: return "person.crop.circle.badge.questionmark"
        case .statBased: return "chart.bar.xaxis"
        case .outcomeBased: return "flag.checkered"
        case .custom: return "wand.and.stars"
        case .politics: return "building.columns"
        case .food: return "fork.knife"
        case .lifeEvents: return "heart.text.square"
        }
    }
    var shortDescription: String {
        switch self {
        case .predefined: return "Pick from a set of 25 possible game events. Everyone bets on the same events."
        case .draftTeam: return "Draft 5 players you think will perform best. Compete for the top team!"
        case .randomPlayer: return "A random player is chosen for each user. Bet on their performance."
        case .statBased: return "Bet on specific stats (e.g., home runs, points, assists) for the game."
        case .outcomeBased: return "Bet on the final outcome or winner of the game."
        case .custom: return "Create your own unique bet type for your party."
        case .politics: return "Bet on political events, elections, or debates."
        case .food: return "Bet on food challenges, eating contests, or culinary outcomes."
        case .lifeEvents: return "Bet on personal milestones, life events, or fun predictions."
        }
    }
    var detailedDescription: String {
        switch self {
        case .predefined:
            return "Predefined Bet lets you select 15 of 25 potential game events you think will happen. Everyone in the party chooses from the same 25 events. At the end of the game, whoever got the most right wins the entire pot."
        case .draftTeam:
            return "Draft Team Bet allows you to pick 5 players you think will perform the best in the game. Each party member drafts their own team. At the end, the team with the highest combined stats wins the pot."
        case .randomPlayer:
            return "Random Player Bet assigns each user a random player from the game. You bet on how well your assigned player will perform."
        case .statBased:
            return "Stat-Based Bet lets you bet on specific statistics, like home runs, points, or assists. You can customize which stats to bet on."
        case .outcomeBased:
            return "Outcome-Based Bet is a simple bet on the final outcome or winner of the game."
        case .custom:
            return "Custom Bet lets you create your own unique betting rules and events for your party."
        case .politics:
            return "Politics Bet lets you wager on the outcome of elections, debates, or political events. Examples: 'Who will win the next election?', 'Will a certain bill pass?'."
        case .food:
            return "Food Bet lets you wager on food challenges, eating contests, or culinary outcomes. Examples: 'Who can eat the most hot dogs?', 'Will someone try a new cuisine?'."
        case .lifeEvents:
            return "Life Events Bet lets you wager on personal milestones, events, or fun predictions about friends. Examples: 'Who will get a new job first?', 'Will someone move cities this year?'."
        }
    }
}

#Preview {
    PartyLobbyView(
        navPath: .constant(NavigationPath()),
        game: BaseballGame(
            id: 1,
            home_team_name: "New York Yankees",
            away_team_name: "Boston Red Sox",
            date: "2025-06-05T00:00:00Z"
        ),
        gameName: "New York Yankees vs Boston Red Sox",
        email: "test@example.com"
    )
    .environment(\.supabaseClient, .development)
}
