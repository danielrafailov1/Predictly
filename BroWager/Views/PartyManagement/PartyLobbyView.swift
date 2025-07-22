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
    @State private var selectedBetType: BetType = .normal
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
                                    .keyboardType(.asciiCapable)
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
                                ForEach([BetType.normal, .timed, .contest], id: \ .self) { type in
                                    PartyBetTypeCard(
                                        betType: type,
                                        isSelected: selectedBetType == type,
                                        showTutorial: { tutorialBetType = type },
                                        select: { selectedBetType = type },
                                        showDescription: selectedBetType == type
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Dynamic Bet Type Form
                        Group {
                            switch selectedBetType {
                            case .normal:
                                EmptyView()
                            case .timed:
                                TimedBetForm(betDetails: $betDetails)
                            case .contest:
                                ContestBetForm(betDetails: $betDetails)
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
                                .background((!betDetails.partyName.isEmpty && !betDetails.betAmount.isEmpty && Int(betDetails.betAmount) != nil) ? Color.green : Color.gray)
                                .cornerRadius(16)
                                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(betDetails.partyName.isEmpty || betDetails.betAmount.isEmpty || Int(betDetails.betAmount) == nil)
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
        .sheet(item: $pendingPartySettings) { _ in
            Text("Game event view is no longer available.")
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
        betDetails.partyName = "\(randomAdjective) \(randomNoun)"
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

struct TimedBetForm: View {
    @Binding var betDetails: PartyLobbyView.BetDetails
    var body: some View {
        EmptyView()
    }
}

struct ContestBetForm: View {
    @Binding var betDetails: PartyLobbyView.BetDetails
    var body: some View {
        EmptyView()
    }
}

// Add/Update PartyBetTypeCard and BetType extension:
struct PartyBetTypeCard: View {
    let betType: BetType
    var isSelected: Bool
    var showTutorial: () -> Void = {}
    var select: () -> Void = {}
    var showDescription: Bool = false
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
                if showDescription {
                    Text(betType.shortDescription)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        case .normal: return "list.bullet.rectangle.portrait"
        case .timed: return "timer"
        case .contest: return "trophy"
        }
    }
    var shortDescription: String {
        switch self {
        case .normal: return "Standard bet."
        case .timed: return "Timed bet."
        case .contest: return "Contest bet."
        }
    }
    var detailedDescription: String {
        switch self {
        case .normal: return "A standard bet with no time constraints."
        case .timed: return "A bet that must be completed within a certain time."
        case .contest: return "A competitive bet with multiple participants."
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
