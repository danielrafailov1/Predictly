import Foundation
import SwiftUI
import Supabase

struct PartyNavigation: Hashable {
    let party_code: String
    let email: String
}

struct MyPartiesView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var parties: [Party] = []
    @State private var openParties: [Party] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPartyDetails: (party_code: String, email: String)? = nil
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
    
    // MARK: - Chunked Loading Properties
    @State private var isLoadingMore = false
    @State private var hasMoreParties = true
    @State private var currentOffset = 0
    private let chunkSize = 20 // Load 20 parties at a time
    
    // Track loaded party IDs to avoid duplicates
    @State private var loadedPartyIds: Set<Int64> = []
    
    // Add loading state tracking to prevent concurrent operations
    @State private var isCurrentlyLoading = false

    enum PartyFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case wins = "Wins"
        case losses = "Losses"
        case open = "Open"
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .active: return "Active"
            case .wins: return "Wins"
            case .losses: return "Losses"
            case .open: return "Open"
            }
        }
        
        var fullName: String {
            switch self {
            case .active: return "Active"
            case .wins: return "Wins"
            case .losses: return "Losses"
            case .open: return "Open Parties"
            }
        }
    }

    var filteredParties: [Party] {
        switch partyFilter {
        case .active:
            return parties.filter { party in
                // Party is active if:
                // 1. Game status is "waiting" (not started yet), OR
                // 2. Game status is not "ended" AND not in wins/losses
                print("The party status is\(party.game_status)")
                
                if party.game_status == "waiting" {
                    return true
                }
                
                // For other statuses, check if it's not in wins or losses
                guard let partyId = party.id else { return false }
                return !wonPartyIds.contains(partyId) && !lostPartyIds.contains(partyId)
            }
        case .wins:
            return parties.filter { party in
                guard let partyId = party.id else { return false }
                // Only show as win if game is actually ended and marked as win
                let isWinner = wonPartyIds.contains(partyId)
                let gameEnded = party.status != "Waiting"
                return isWinner && gameEnded
            }
        case .losses:
            return parties.filter { party in
                guard let partyId = party.id else { return false }
                // Only show as loss if game is actually ended and marked as loss
                let isLoser = lostPartyIds.contains(partyId)
                let gameEnded = party.status != "Waiting"
                return isLoser && gameEnded
            }
        case .open:
            return openParties
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
    
    // MARK: - Optimized Parties List View with LazyVStack
    private var partiesListView: some View {
        List {
            ForEach(Array(partyRows.enumerated()), id: \.element.party.id) { index, row in
                Group {
                    if partyFilter == .open {
                        OpenPartyCard(
                            party: row.party,
                            memberCount: row.memberCount,
                            betType: row.betType,
                            backgroundColor: cardBackgroundColor(for: row.party),
                            onJoin: {
                                Task { await joinOpenParty(row.party) }
                            }
                        )
                    } else {
                        NavigationLink(value: PartyNavigation(party_code: row.party.party_code ?? "", email: email)) {
                            PartyCard(
                                party: row.party,
                                memberCount: row.memberCount,
                                betType: row.betType,
                                backgroundColor: cardBackgroundColor(for: row.party)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if partyFilter != .open {
                        Button(role: .destructive) {
                            Task { await handlePartyDeletion(row.party) }
                        } label: {
                            Label(isPartyLeader(row.party) ? "Delete" : "Leave",
                                  systemImage: isPartyLeader(row.party) ? "trash" : "rectangle.portrait.and.arrow.right")
                        }
                        
                        if partyFilter == .active {
                            Button {
                                archiveParty(row.party)
                            } label: {
                                Label("Archive", systemImage: "archivebox")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .onAppear {
                    if index == partyRows.count - 3 && !isLoadingMore && hasMoreParties {
                        Task {
                            await loadMoreParties()
                        }
                    }
                }
            }
            
            if isLoadingMore {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading more parties...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
                        await resetAndLoadParties()
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
                Image(systemName: partyFilter == .open ? "globe" : "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.5))
                Text(partyFilter == .open ? "No open parties" : "No \(partyFilter.fullName.lowercased()) parties")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                if partyFilter == .active {
                    Text("Create a new party to get started")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                } else if partyFilter == .open {
                    Text("No open parties available to join")
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
                        Text(partyFilter == .open ? "Open Parties" : "My Parties")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(partyFilter == .open ? "Discover and join public parties" : "View and manage your active parties")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 16)

                    Spacer().frame(height: 18)

                    Picker("Party Filter", selection: $partyFilter) {
                        ForEach(PartyFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 20) // Slightly reduced padding to give more space
                    .onChange(of: partyFilter) { _, newValue in
                        Task {
                            await handleFilterChange(newValue)
                        }
                    }

                    Spacer().frame(height: 14)

                    if partyFilter != .open {
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
                    }
                    
                    // Content section - takes remaining space
                    partyListSection
                }
            }
            .navigationDestination(for: PartyNavigation.self) { details in
                PartyDetailsView(party_code: details.party_code, email: details.email)
            }
        }
        .sheet(isPresented: $showJoinParty, onDismiss: {
            Task { await resetAndLoadParties() }
        }) {
            JoinPartyView(email: email)
                .environment(\.supabaseClient, supabaseClient)
        }
        .sheet(isPresented: $showPartyInvites, onDismiss: {
            Task { await resetAndLoadParties() }
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
                await initializeView()
            }
            setupTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .refreshable {
            await resetAndLoadParties()
        }
    }

    // MARK: - Helper Functions
    
    /// Initialize the view with user data and initial party load
    private func initializeView() async {
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
        
        await resetAndLoadParties()
        
        if let userEmail = sessionManager.userEmail {
            profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
        }
    }
    
    /// Handle filter change with proper reset
    private func handleFilterChange(_ newFilter: PartyFilter) async {
        // Prevent concurrent loading operations
        guard !isCurrentlyLoading else { return }
        
        // Clear error message when changing filters
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
        
        if newFilter == .open {
            await loadOpenParties()
        } else {
            // Reset pagination state when switching filters
            resetPaginationState()
            await loadPartiesChunked(isInitialLoad: true)
        }
    }
    
    /// Reset pagination state
    private func resetPaginationState() {
        currentOffset = 0
        hasMoreParties = true
        loadedPartyIds.removeAll()
        parties.removeAll()
    }
    
    /// Reset and load parties from scratch
    private func resetAndLoadParties() async {
        // Prevent concurrent loading operations
        guard !isCurrentlyLoading else {
            print("⚠️ Skipping reload - already loading")
            return
        }
        
        resetPaginationState()
        if partyFilter == .open {
            await loadOpenParties()
        } else {
            await loadPartiesChunked(isInitialLoad: true)
        }
    }
    
    /// Archive a party locally
    private func archiveParty(_ party: Party) {
        archivedParties.append(party)
        parties.removeAll { $0.id == party.id }
    }
    
    /// Sets up a repeating timer to automatically refresh the party list.
    private func setupTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            print("⏳ Auto-refreshing parties...")
            Task {
                // Only refresh if not currently loading and user is still on the same filter
                guard !self.isCurrentlyLoading else {
                    print("⚠️ Skipping auto-refresh - already loading")
                    return
                }
                
                // Do a complete refresh to ensure data consistency
                await self.resetAndLoadParties()
            }
        }
    }
    
    /// Load more parties for pagination
    private func loadMoreParties() async {
        guard !isLoadingMore && hasMoreParties && partyFilter != .open && !isCurrentlyLoading else { return }
        
        DispatchQueue.main.async {
            self.isLoadingMore = true
        }
        
        await loadPartiesChunked(isInitialLoad: false)
        
        DispatchQueue.main.async {
            self.isLoadingMore = false
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
        
        print("🗑️ Handling party deletion for party: \(party.party_name ?? "Unknown") (ID: \(partyId))")
        
        do {
            if isPartyLeader(party) {
                print("🗑️ User is party leader - deleting entire party")
                try await deleteEntireParty(partyId: partyId)
            } else {
                print("🗑️ User is not party leader - leaving party")
                try await leaveParty(partyId: partyId)
            }
            
            // Update local state immediately
            DispatchQueue.main.async {
                // Remove from all local arrays
                self.parties.removeAll { $0.id == partyId }
                self.openParties.removeAll { $0.id == partyId }
                self.wonPartyIds.remove(partyId)
                self.lostPartyIds.remove(partyId)
                self.loadedPartyIds.remove(partyId)
                self.memberCounts.removeValue(forKey: partyId)
                
                print("✅ Updated local state after party deletion")
            }
            
            // Refresh the current view to ensure consistency
            await resetAndLoadParties()
            
        } catch {
            print("❌ Error handling party deletion: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to \(self.isPartyLeader(party) ? "delete party" : "leave party"): \(error.localizedDescription)"
            }
        }
    }
    
    /// Delete the entire party (leader only)
    private func deleteEntireParty(partyId: Int64) async throws {
        print("🗑️ Starting deletion of party ID: \(partyId)")
        
        // Convert to string for database operations
        let partyIdString = String(partyId)
        
        // Delete in the correct order to avoid foreign key constraints
        // 1. Delete all party members (kicks everyone out)
        print("🗑️ Deleting party members...")
        let membersResult = try await supabaseClient
            .from("Party Members")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        print("✅ Deleted party members, affected rows: \(membersResult.count ?? 0)")
        
        // 2. Delete all user bets for this party
        print("🗑️ Deleting user bets...")
        let betsResult = try await supabaseClient
            .from("User Bets")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        print("✅ Deleted user bets, affected rows: \(betsResult.count ?? 0)")
        
        // 3. Delete all party invites
        print("🗑️ Deleting party invites...")
        let invitesResult = try await supabaseClient
            .from("Party Invites")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        print("✅ Deleted party invites, affected rows: \(invitesResult.count ?? 0)")
        
        // 4. Finally delete the party itself
        print("🗑️ Deleting party...")
        let partyResult = try await supabaseClient
            .from("Parties")
            .delete()
            .eq("id", value: partyIdString)
            .execute()
        print("✅ Deleted party, affected rows: \(partyResult.count ?? 0)")
        
        print("✅ Successfully deleted entire party with ID: \(partyId)")
    }
    
    /// Leave the party (non-leader only)
    private func leaveParty(partyId: Int64) async throws {
        let partyIdString = String(partyId)
        
        try await supabaseClient
            .from("Party Members")
            .delete()
            .eq("party_id", value: partyIdString)
            .eq("user_id", value: userId)
            .execute()
        
        try await supabaseClient
            .from("User Bets")
            .delete()
            .eq("party_id", value: partyIdString)
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Successfully left party with ID: \(partyId)")
    }

    /// Join an open party
    private func joinOpenParty(_ party: Party) async {
        guard let partyId = party.id else {
            print("❌ Cannot join party: missing party ID")
            return
        }
        
        do {
            let memberCheckResponse = try await supabaseClient
                .from("Party Members")
                .select("id")
                .eq("party_id", value: String(partyId))
                .eq("user_id", value: userId)
                .execute()
            
            struct MemberCheck: Decodable { let id: Int64 }
            let existingMembers = try JSONDecoder().decode([MemberCheck].self, from: memberCheckResponse.data)
            
            if !existingMembers.isEmpty {
                DispatchQueue.main.async {
                    self.errorMessage = "You're already a member of this party"
                }
                return
            }
            
            let memberData = [
                "party_id": String(partyId),
                "user_id": userId,
                "joined_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            try await supabaseClient
                .from("Party Members")
                .insert(memberData)
                .execute()
            
            await resetAndLoadParties()
            
            print("✅ Successfully joined party: \(party.party_name ?? "Unknown")")
            
        } catch {
            print("❌ Error joining party: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to join party: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadOpenParties() async {
        guard !userId.isEmpty else {
            print("⚠️ Attempted to load open parties but userId is empty.")
            return
        }
        
        // Set loading state to prevent concurrent operations
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        struct OpenPartyRow: Decodable {
            let id: Int64?
            let party_name: String?
            let bet_type: String?
            let party_code: String?
            let created_by: String?
            let privacy_option: String?
            let game_status: String
            let created_at: String?
            let bet: String?
            let terms: String?
            let options: [String]?
            let max_members: Int?
            let status: String?
            let max_selections: Int?
            let timer_duration: Int?
            let allow_early_finish: Bool?
            let contest_unit: String?
            let contest_target: Int?
            let allow_ties: Bool?
        }
        
        struct UserPartyRow: Decodable {
            let party_id: Int64
        }
        
        do {
            // Get parties user is already a member of
            let userPartiesResponse = try await supabaseClient
                .from("Party Members")
                .select("party_id")
                .eq("user_id", value: userId)
                .execute()
            
            let userPartyRows = try JSONDecoder().decode([UserPartyRow].self, from: userPartiesResponse.data)
            let userPartyIds = Set(userPartyRows.map { $0.party_id })
            
            var allOpenParties: [OpenPartyRow] = []
            
            // Query for "Open" parties - including all required fields
            let openResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by, privacy_option, game_status, created_at, bet, terms, options, max_members, status, max_selections, timer_duration, allow_early_finish, contest_unit, contest_target, allow_ties")
                .eq("privacy_option", value: "Open")
                .neq("game_status", value: "ended") // Exclude ended games
                .order("created_at", ascending: false)
                .range(from: 0, to: chunkSize - 1)
                .execute()
            
            let openParties = try JSONDecoder().decode([OpenPartyRow].self, from: openResponse.data)
            allOpenParties.append(contentsOf: openParties)
            
            // Query for "Public" parties - including all required fields
            let publicResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by, privacy_option, game_status, created_at, bet, terms, options, max_members, status, max_selections, timer_duration, allow_early_finish, contest_unit, contest_target, allow_ties")
                .eq("privacy_option", value: "Public")
                .neq("game_status", value: "ended") // Exclude ended games
                .order("created_at", ascending: false)
                .range(from: 0, to: chunkSize - 1)
                .execute()
            
            let publicParties = try JSONDecoder().decode([OpenPartyRow].self, from: publicResponse.data)
            allOpenParties.append(contentsOf: publicParties)
            
            // Filter out parties that user is already member of
            let availableOpenParties = allOpenParties.filter { party in
                guard let partyId = party.id else { return false }
                return !userPartyIds.contains(partyId)
            }
            
            let loadedOpenParties = availableOpenParties.compactMap { p -> Party? in
                guard let partyId = p.id else { return nil }
                
                return Party(
                    id: partyId,
                    party_code: p.party_code,
                    created_by: p.created_by,
                    party_name: p.party_name,
                    privacy_option: p.privacy_option,
                    max_members: p.max_members,
                    bet: p.bet,
                    bet_type: p.bet_type,
                    options: p.options,
                    terms: p.terms,
                    status: p.status,
                    game_status: p.game_status,
                    max_selections: p.max_selections,
                    timer_duration: p.timer_duration,
                    allow_early_finish: p.allow_early_finish,
                    contest_unit: p.contest_unit,
                    contest_target: p.contest_target,
                    allow_ties: p.allow_ties
                )
            }
            
            // Load member counts for open parties
            await withTaskGroup(of: Void.self) { group in
                for party in loadedOpenParties {
                    guard let partyId = party.id else { continue }
                    group.addTask {
                        await self.loadMemberCount(for: partyId)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.openParties = loadedOpenParties
                print("✅ Loaded \(loadedOpenParties.count) open parties")
            }
            
        } catch {
            print("❌ Error loading open parties: \(error)")
            DispatchQueue.main.async {
                if self.partyFilter == .open {
                    self.errorMessage = "Error loading open parties: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Load member count for a specific party
    private func loadMemberCount(for partyId: Int64) async {
        do {
            let response = try await supabaseClient
                .from("Party Members")
                .select("id", count: .exact)
                .eq("party_id", value: String(partyId))
                .execute()
            
            let count = response.count ?? 0
            DispatchQueue.main.async {
                self.memberCounts[partyId] = count
            }
        } catch {
            print("❌ Error loading member count for party \(partyId): \(error)")
        }
    }

    func loadPartiesChunked(isInitialLoad: Bool, silentRefresh: Bool = false) async {
        // Prevent concurrent loading operations
        if isCurrentlyLoading {
            print("⚠️ Skipping loadPartiesChunked - already loading")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        if isInitialLoad && !silentRefresh {
            DispatchQueue.main.async {
                self.isLoading = true
                self.errorMessage = nil
            }
        }
        
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
            let created_by: String?
            let privacy_option: String?
            let created_at: String?
            let bet: String?
            let terms: String?
            let options: [String]?
            let max_members: Int?
            let status: String?
            let game_status: String
            let max_selections: Int?
            let timer_duration: Int?
            let allow_early_finish: Bool?
            let contest_unit: String?
            let contest_target: Int?
            let allow_ties: Bool?
        }
        struct WinRow: Decodable { let party_id: Int64 }

        do {
            // Get user's party IDs first
            let memberResponse = try await supabaseClient
                .from("Party Members")
                .select("party_id")
                .eq("user_id", value: userId)
                .execute()
            
            struct PartyMemberRow: Decodable { let party_id: Int64 }
            let memberRows = try JSONDecoder().decode([PartyMemberRow].self, from: memberResponse.data)
            let userPartyIds = Set(memberRows.map { $0.party_id })
            
            guard !userPartyIds.isEmpty else {
                DispatchQueue.main.async {
                    self.parties = []
                    self.wonPartyIds = []
                    self.lostPartyIds = []
                    self.hasMoreParties = false
                    if isInitialLoad { self.isLoading = false }
                }
                return
            }
            
            // Convert userPartyIds to strings for the IN filter
            let partyIdStrings = userPartyIds.map { String($0) }
            
            // For initial loads, fetch ALL parties to ensure we have complete data
            let rangeEnd = isInitialLoad ? 999 : currentOffset + chunkSize - 1
            
            // Fetch only parties where user is a member, with pagination
            let partiesResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by, privacy_option, game_status, created_at, bet, terms, options, max_members, status, max_selections, timer_duration, allow_early_finish, contest_unit, contest_target, allow_ties")
                .in("id", values: partyIdStrings)
                .order("created_at", ascending: false)
                .range(from: isInitialLoad ? 0 : currentOffset, to: rangeEnd)
                .execute()
            
            let partiesChunk = try JSONDecoder().decode([PartyRow].self, from: partiesResponse.data)
            
            // Always load win/loss data for complete state
            async let winsTask = supabaseClient
                .from("User Bets")
                .select("party_id")
                .eq("user_id", value: userId)
                .eq("is_winner", value: true)
                .execute()
            
            async let lossesTask = supabaseClient
                .from("User Bets")
                .select("party_id")
                .eq("user_id", value: userId)
                .eq("is_winner", value: false)
                .execute()
            
            let (winsResponse, lossesResponse) = try await (winsTask, lossesTask)
            
            let winRows = try JSONDecoder().decode([WinRow].self, from: winsResponse.data)
            let lossRows = try JSONDecoder().decode([WinRow].self, from: lossesResponse.data)
            
            let winPartyIds = Set(winRows.map { $0.party_id })
            let lossPartyIds = Set(lossRows.map { $0.party_id })
            
            let newParties = partiesChunk.compactMap { p -> Party? in
                guard let partyId = p.id else { return nil }
                
                // For pagination, avoid duplicates
                if !isInitialLoad && loadedPartyIds.contains(partyId) {
                    return nil
                }
                
                return Party(
                    id: partyId,
                    party_code: p.party_code,
                    created_by: p.created_by,
                    party_name: p.party_name,
                    privacy_option: p.privacy_option,
                    max_members: p.max_members,
                    bet: p.bet,
                    bet_type: p.bet_type,
                    options: p.options,
                    terms: p.terms,
                    status: p.status,
                    game_status: p.game_status,
                    max_selections: p.max_selections,
                    timer_duration: p.timer_duration,
                    allow_early_finish: p.allow_early_finish,
                    contest_unit: p.contest_unit,
                    contest_target: p.contest_target,
                    allow_ties: p.allow_ties
                )
            }
            
            // Load member counts for new parties concurrently
            await withTaskGroup(of: Void.self) { group in
                for party in newParties {
                    guard let partyId = party.id else { continue }
                    group.addTask {
                        await self.loadMemberCount(for: partyId)
                    }
                }
            }
            
            DispatchQueue.main.async {
                // Always update win/loss data
                self.wonPartyIds = winPartyIds
                self.lostPartyIds = lossPartyIds
                
                // Track loaded party IDs
                for party in newParties {
                    if let partyId = party.id {
                        self.loadedPartyIds.insert(partyId)
                    }
                }
                
                if isInitialLoad {
                    // For initial loads, replace all data
                    self.parties = newParties
                    self.currentOffset = newParties.count
                    self.hasMoreParties = newParties.count == self.chunkSize && !silentRefresh
                } else {
                    // Append for pagination
                    self.parties.append(contentsOf: newParties)
                    self.currentOffset += newParties.count
                    self.hasMoreParties = newParties.count == self.chunkSize
                }
                
                if isInitialLoad { self.isLoading = false }
                
                print("✅ Loaded \(newParties.count) parties. Total: \(self.parties.count)")
                print("   Active: \(self.filteredParties.count) (after filtering)")
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error loading parties: \(error.localizedDescription)"
                if isInitialLoad { self.isLoading = false }
            }
            print("❌ Error loading parties: \(error)")
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

struct OpenPartyCard: View {
    let party: Party
    let memberCount: Int
    let betType: String
    let backgroundColor: Color
    let onJoin: () -> Void

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
                VStack(alignment: .trailing, spacing: 4) {
                    Text(betType)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Button(action: onJoin) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Join")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                }
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
