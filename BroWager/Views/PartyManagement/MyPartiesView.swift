import Foundation
import SwiftUI
import Supabase

struct PartyNavigation: Hashable {
    let partyCode: String
    let email: String
}

struct MyPartiesView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var parties: [Party] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPartyDetails: (partyCode: String, email: String)? = nil
    @State private var isShowingDetails = false
    @State private var showJoinParty = false
    @State private var showPartyInvites = false
    @State private var userId: String = ""
    @State private var showProfile = false
    @State private var memberCounts: [Int64: Int] = [:]
    @State private var profileImage: Image? = nil
    @EnvironmentObject var sessionManager: SessionManager

    let email: String

    @State private var archivedParties: [Party] = []
    @State private var deletedParties: [Party] = []
    @State private var partyFilter: PartyFilter = .active
    @State private var wonPartyIds: Set<Int64> = []
    @State private var lostPartyIds: Set<Int64> = []
    
    // Timer for auto-refreshing party list
    @State private var refreshTimer: Timer?

    enum PartyFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case wins = "Wins"
        case losses = "Losses"
        var id: String { rawValue }
    }

    var filteredParties: [Party] {
        switch partyFilter {
        case .active:
            return parties.filter { !wonPartyIds.contains($0.id ?? -1) && !lostPartyIds.contains($0.id ?? -1) }
        case .wins:
            return parties.filter { wonPartyIds.contains($0.id ?? -1) }
        case .losses:
            return parties.filter { lostPartyIds.contains($0.id ?? -1) }
        }
    }

    private var partyRows: [(party: Party, memberCount: Int, betType: String)] {
        let currentMemberCounts = memberCounts
        return filteredParties.compactMap { party in
            guard let id = party.id else { return nil }
            return (
                party: party,
                memberCount: currentMemberCounts[id] ?? 1,
                betType: party.bet_type ?? ""
            )
        }
    }

    private func cardBackgroundColor(for party: Party) -> Color {
        guard let partyId = party.id else { return Color.white.opacity(0.08) }

        if wonPartyIds.contains(partyId) {
            return Color.green.opacity(0.2)
        } else if lostPartyIds.contains(partyId) {
            return Color.red.opacity(0.2)
        } else {
            return Color.white.opacity(0.08)
        }
    }
    
    private var partiesListView: some View {
        List {
            ForEach(partyRows, id: \.party.id) { row in
                NavigationLink(value: PartyNavigation(partyCode: row.party.party_code ?? "", email: email)) {
                    PartyCard(
                        party: row.party,
                        memberCount: row.memberCount,
                        betType: row.betType,
                        // Using the helper function here simplifies the view body
                        backgroundColor: cardBackgroundColor(for: row.party)
                    )
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await handlePartyDeletion(row.party) }
                    } label: {
                        Label(isPartyLeader(row.party) ? "Delete Party" : "Leave Party",
                              systemImage: isPartyLeader(row.party) ? "trash" : "rectangle.portrait.and.arrow.right")
                    }
                    
                    if partyFilter == .active {
                        Button {
                            archivedParties.append(row.party)
                            parties.removeAll { $0.id == row.party.id }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
    }
    
    // Fixed partyListSection with proper layout structure
    @ViewBuilder
    private var partyListSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading parties...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                Text(error)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Retry") {
                    Task {
                        await loadParties(isInitialLoad: true)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            Spacer()
        } else if filteredParties.isEmpty {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.5))
                Text("No \(partyFilter.rawValue.lowercased()) parties")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                if partyFilter == .active {
                    Text("Create a new party to get started")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
        } else {
            partiesListView
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header section - always visible at top
                    VStack(spacing: 8) {
                        Text("My Parties")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("View and manage your active parties")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 16)

                    Spacer().frame(height: 18)

                    Picker("Party Filter", selection: $partyFilter) {
                        ForEach(PartyFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 14)

                    Button(action: { showPartyInvites = true }) {
                        HStack {
                            Image(systemName: "envelope.open.fill")
                            Text("Party Invites")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    
                    // Content section - takes remaining space
                    partyListSection
                }
            }
            .navigationDestination(for: PartyNavigation.self) { details in
                PartyDetailsView(partyCode: details.partyCode, email: details.email)
            }
        }
        .sheet(isPresented: $showJoinParty, onDismiss: {
            Task { await loadParties(isInitialLoad: true) }
        }) {
            JoinPartyView(email: email)
                .environment(\.supabaseClient, supabaseClient)
        }
        .sheet(isPresented: $showPartyInvites, onDismiss: {
            Task { await loadParties(isInitialLoad: true) }
        }) {
            if !userId.isEmpty {
                PartyInvitesView(userId: userId)
                    .environment(\.supabaseClient, supabaseClient)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: .constant(NavigationPath()), email: email)
        }
        .onAppear {
            Task {
                do {
                    let userResponse = try await supabaseClient
                        .from("Login Information")
                        .select("user_id")
                        .eq("email", value: email)
                        .limit(1)
                        .execute()
                    struct UserIdRow: Decodable { let user_id: String }
                    let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResponse.data)
                    if let first = userIdRows.first {
                        userId = first.user_id
                    }
                } catch {
                    print("[MyPartiesView] Failed to fetch userId: \(error)")
                }
                await loadParties(isInitialLoad: true)
                if let userEmail = sessionManager.userEmail {
                    profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
                }
            }
            // Start the auto-refresh timer when the view appears
            setupTimer()
        }
        .onDisappear {
            // Stop the timer when the view disappears to conserve resources
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Helper Functions
    
    /// Sets up a repeating timer to automatically refresh the party list.
    private func setupTimer() {
        // Invalidate any existing timer to prevent duplicates.
        refreshTimer?.invalidate()
        // Schedule a new timer on the main thread.
        // A 30-second interval provides timely updates without excessive network requests.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            print("⏳ Auto-refreshing parties...")
            Task {
                // Perform a background refresh; don't show the full-screen loader.
                await loadParties(isInitialLoad: false)
            }
        }
    }
    
    /// Check if the current user is the party leader
    private func isPartyLeader(_ party: Party) -> Bool {
        return party.created_by == userId
    }
    
    /// Handle party deletion based on user role
    private func handlePartyDeletion(_ party: Party) async {
        guard let partyId = party.id else {
            print("❌ Cannot delete party: missing party ID")
            return
        }
        
        do {
            if isPartyLeader(party) {
                // Leader deletes the entire party for everyone
                try await deleteEntireParty(partyId: partyId)
            } else {
                // Non-leader leaves the party (removes themselves)
                try await leaveParty(partyId: partyId)
            }
            
            // Remove from local state and update win/loss sets
            DispatchQueue.main.async {
                self.parties.removeAll { $0.id == partyId }
                self.wonPartyIds.remove(partyId)
                self.lostPartyIds.remove(partyId)
            }
            
        } catch {
            print("❌ Error handling party deletion: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to \(self.isPartyLeader(party) ? "delete party" : "leave party"): \(error.localizedDescription)"
            }
        }
    }
    
    /// Delete the entire party (leader only)
    private func deleteEntireParty(partyId: Int64) async throws {
        let partyIdString = String(partyId)
        
        // Delete all party members first (cascade delete)
        try await supabaseClient
            .from("Party Members")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        
        // Delete all user bets for this party
        try await supabaseClient
            .from("User Bets")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        
        // Delete any party invites
        try await supabaseClient
            .from("Party Invites")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        
        // Finally, delete the party itself
        try await supabaseClient
            .from("Parties")
            .delete()
            .eq("id", value: partyIdString)
            .execute()
        
        print("✅ Successfully deleted entire party with ID: \(partyId)")
    }
    
    /// Leave the party (non-leader only)
    private func leaveParty(partyId: Int64) async throws {
        let partyIdString = String(partyId)
        
        // Remove user from party members
        try await supabaseClient
            .from("Party Members")
            .delete()
            .eq("party_id", value: partyIdString)
            .eq("user_id", value: userId)
            .execute()
        
        // Remove user's bets for this party
        try await supabaseClient
            .from("User Bets")
            .delete()
            .eq("party_id", value: partyIdString)
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Successfully left party with ID: \(partyId)")
    }

    /// Loads all party data associated with the current user.
    /// - Parameter isInitialLoad: Determines whether to show the main loading indicator.
    ///   Set to `true` for the first load or manual refreshes.
    ///   Set to `false` for silent background refreshes.
    func loadParties(isInitialLoad: Bool) async {
        if isInitialLoad {
            isLoading = true
        }
        errorMessage = nil
        
        guard !userId.isEmpty else {
            print("⚠️ Attempted to load parties but userId is empty.")
            DispatchQueue.main.async {
                self.errorMessage = "Could not identify your user account."
                if isInitialLoad { self.isLoading = false }
            }
            return
        }
        
        struct PartyRow: Decodable {
            let id: Int64?
            let party_name: String?
            let bet_type: String?
            let party_code: String?
            let created_by: String? // This is actually UUID in DB but comes as String
        }
        struct WinRow: Decodable { let party_id: Int64 }
        struct PartyMemberRow: Decodable { let party_id: Int64 }

        do {
            // First get user's party IDs
            let memberResponse = try await supabaseClient
                .from("Party Members")
                .select("party_id")
                .eq("user_id", value: userId)
                .execute()
            
            let memberRows = try JSONDecoder().decode([PartyMemberRow].self, from: memberResponse.data)
            let userPartyIds = Set(memberRows.map { $0.party_id })
            
            // If user has no parties, return empty state
            guard !userPartyIds.isEmpty else {
                DispatchQueue.main.async {
                    self.parties = []
                    self.wonPartyIds = []
                    self.lostPartyIds = []
                    if isInitialLoad { self.isLoading = false }
                }
                return
            }
            
            // Fetch all parties and filter locally
            let partiesResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by")
                .execute()
            let partiesData = partiesResponse.data
            let allParties = try JSONDecoder().decode([PartyRow].self, from: partiesData)
            
            // Filter to only parties where user is a member
            let parties = allParties.filter { party in
                guard let partyId = party.id else { return false }
                return userPartyIds.contains(partyId)
            }
            
            // Fetch winning party IDs for this user
            let userWinsResponse = try await supabaseClient
                .from("User Bets")
                .select("party_id")
                .eq("user_id", value: userId)
                .eq("is_winner", value: true)
                .execute()
            let winsData = userWinsResponse.data
            let winRows = try JSONDecoder().decode([WinRow].self, from: winsData)
            let winPartyIds = Set(winRows.map { $0.party_id })
            
            // Fetch losing party IDs for this user
            let userLossesResponse = try await supabaseClient
                .from("User Bets")
                .select("party_id")
                .eq("user_id", value: userId)
                .eq("is_winner", value: false)
                .execute()
            let lossesData = userLossesResponse.data
            let lossRows = try JSONDecoder().decode([WinRow].self, from: lossesData)
            let lossPartyIds = Set(lossRows.map { $0.party_id })
            
            let loadedParties = parties.compactMap { p -> Party? in
                // Skip parties with nil IDs
                guard let partyId = p.id else { return nil }
                
                return Party(
                    id: partyId,
                    party_name: p.party_name ?? "Unknown Party",
                    party_code: p.party_code ?? "",
                    created_by: p.created_by ?? "",
                    bet_type: p.bet_type,
                    max_members: nil,
                    status: nil,
                    created_at: nil,
                    bet: nil,
                    terms: nil,
                    options: nil,
                    game_status: nil,
                    privacy_option: nil
                )
            }
            
            DispatchQueue.main.async {
                self.parties = loadedParties
                self.wonPartyIds = winPartyIds
                self.lostPartyIds = lossPartyIds
                if isInitialLoad { self.isLoading = false }
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Error loading parties: \(error.localizedDescription)"
                if isInitialLoad { isLoading = false }
            }
            print("Error loading parties: \(error)")
        }
    }
    
    private func fetchCreatorDetails(for party: Party) async -> String? {
        do {
            let response = try await supabaseClient
                .from("Login Information")
                .select("email")
                .eq("user_id", value: party.created_by)
                .limit(1)
                .execute()
            struct CreatorInfo: Codable { let email: String }
            let info = try JSONDecoder().decode([CreatorInfo].self, from: response.data)
            return info.first?.email
        } catch {
            print("❌ Error fetching creator details: \(error)")
            return nil
        }
    }
}

struct PartyCard: View {
    let party: Party
    let memberCount: Int
    let betType: String
    let backgroundColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.party_name ?? "Unnamed Party")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Members: \(memberCount)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text(betType)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
