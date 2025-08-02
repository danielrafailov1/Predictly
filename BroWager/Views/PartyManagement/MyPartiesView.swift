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
    @State private var openParties: [Party] = []
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
    
    // MARK: - Chunked Loading Properties
    @State private var isLoadingMore = false
    @State private var hasMoreParties = true
    @State private var currentOffset = 0
    private let chunkSize = 20 // Load 20 parties at a time
    
    // Track loaded party IDs to avoid duplicates
    @State private var loadedPartyIds: Set<Int64> = []

    enum PartyFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case wins = "Wins"
        case losses = "Losses"
        case open = "Open Parties"
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
        ScrollView {
            LazyVStack(spacing: 16) {
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
                            NavigationLink(value: PartyNavigation(partyCode: row.party.party_code ?? "", email: email)) {
                                PartyCard(
                                    party: row.party,
                                    memberCount: row.memberCount,
                                    betType: row.betType,
                                    backgroundColor: cardBackgroundColor(for: row.party)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await handlePartyDeletion(row.party) }
                                } label: {
                                    Label(isPartyLeader(row.party) ? "Delete Party" : "Leave Party",
                                          systemImage: isPartyLeader(row.party) ? "trash" : "rectangle.portrait.and.arrow.right")
                                }
                                
                                if partyFilter == .active {
                                    Button {
                                        archiveParty(row.party)
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .onAppear {
                        // Load more when approaching the end
                        if index == partyRows.count - 3 && !isLoadingMore && hasMoreParties {
                            Task {
                                await loadMoreParties()
                            }
                        }
                    }
                }
                
                // Loading indicator for pagination
                if isLoadingMore {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more parties...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                }
            }
            .padding(.vertical, 8)
        }
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
                Text(partyFilter == .open ? "No open parties" : "No \(partyFilter.rawValue.lowercased()) parties")
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
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 24)
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
                PartyDetailsView(partyCode: details.partyCode, email: details.email)
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
                // For timer refreshes, only refresh the first chunk to avoid disrupting user's scroll position
                if partyFilter == .open {
                    await loadOpenParties()
                } else {
                    await loadPartiesChunked(isInitialLoad: false, silentRefresh: true)
                }
            }
        }
    }
    
    /// Load more parties for pagination
    private func loadMoreParties() async {
        guard !isLoadingMore && hasMoreParties && partyFilter != .open else { return }
        
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
        
        do {
            if isPartyLeader(party) {
                try await deleteEntireParty(partyId: partyId)
            } else {
                try await leaveParty(partyId: partyId)
            }
            
            DispatchQueue.main.async {
                self.parties.removeAll { $0.id == partyId }
                self.wonPartyIds.remove(partyId)
                self.lostPartyIds.remove(partyId)
                self.loadedPartyIds.remove(partyId)
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
        
        try await supabaseClient
            .from("Party Members")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        
        try await supabaseClient
            .from("User Bets")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        
        try await supabaseClient
            .from("Party Invites")
            .delete()
            .eq("party_id", value: partyIdString)
            .execute()
        
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
    
    /// Load open parties that the user can join
    private func loadOpenParties() async {
        guard !userId.isEmpty else {
            print("⚠️ Attempted to load open parties but userId is empty.")
            return
        }
        
        struct OpenPartyRow: Decodable {
            let id: Int64?
            let party_name: String?
            let bet_type: String?
            let party_code: String?
            let created_by: String?
            let privacy_option: String?
        }
        
        struct UserPartyRow: Decodable {
            let party_id: Int64
        }
        
        do {
            let userPartiesResponse = try await supabaseClient
                .from("Party Members")
                .select("party_id")
                .eq("user_id", value: userId)
                .execute()
            
            let userPartyRows = try JSONDecoder().decode([UserPartyRow].self, from: userPartiesResponse.data)
            let userPartyIds = Set(userPartyRows.map { $0.party_id })
            
            var allOpenParties: [OpenPartyRow] = []
            
            // Query for "Open" parties with pagination
            let openResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by, privacy_option")
                .eq("privacy_option", value: "Open")
                .order("created_at", ascending: false)
                .range(from: 0, to: chunkSize - 1)
                .execute()
            
            let openParties = try JSONDecoder().decode([OpenPartyRow].self, from: openResponse.data)
            allOpenParties.append(contentsOf: openParties)
            
            // Query for "Public" parties with pagination
            let publicResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by, privacy_option")
                .eq("privacy_option", value: "Public")
                .order("created_at", ascending: false)
                .range(from: 0, to: chunkSize - 1)
                .execute()
            
            let publicParties = try JSONDecoder().decode([OpenPartyRow].self, from: publicResponse.data)
            allOpenParties.append(contentsOf: publicParties)
            
            let availableOpenParties = allOpenParties.filter { party in
                guard let partyId = party.id else { return false }
                return !userPartyIds.contains(partyId)
            }
            
            let loadedOpenParties = availableOpenParties.compactMap { p -> Party? in
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
                    privacy_option: p.privacy_option
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

    /// Loads parties in chunks for better performance
    /// - Parameters:
    ///   - isInitialLoad: Whether this is the first load (shows main loading indicator)
    ///   - silentRefresh: Whether this is a background refresh (doesn't reset pagination)
    func loadPartiesChunked(isInitialLoad: Bool, silentRefresh: Bool = false) async {
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
        }
        struct WinRow: Decodable { let party_id: Int64 }
        struct PartyMemberRow: Decodable { let party_id: Int64 }

        do {
            // First get user's party IDs if this is initial load or silent refresh
            var userPartyIds: Set<Int64> = []
            
            if isInitialLoad || silentRefresh {
                let memberResponse = try await supabaseClient
                    .from("Party Members")
                    .select("party_id")
                    .eq("user_id", value: userId)
                    .execute()
                
                let memberRows = try JSONDecoder().decode([PartyMemberRow].self, from: memberResponse.data)
                userPartyIds = Set(memberRows.map { $0.party_id })
                
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
            }
            
            // Fetch parties with pagination
            let partiesResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by")
                .order("created_at", ascending: false)
                .range(from: currentOffset, to: currentOffset + chunkSize - 1)
                .execute()
            
            let allPartiesChunk = try JSONDecoder().decode([PartyRow].self, from: partiesResponse.data)
            
            // Filter to only parties where user is a member (if we have userPartyIds)
            let filteredPartiesChunk: [PartyRow]
            if !userPartyIds.isEmpty {
                filteredPartiesChunk = allPartiesChunk.filter { party in
                    guard let partyId = party.id else { return false }
                    return userPartyIds.contains(partyId)
                }
            } else {
                // For pagination, we assume user party filtering was done in initial load
                filteredPartiesChunk = allPartiesChunk
            }
            
            // Load win/loss data if this is initial load or silent refresh
            var winPartyIds: Set<Int64> = []
            var lossPartyIds: Set<Int64> = []
            
            if isInitialLoad || silentRefresh {
                // Fetch wins and losses
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
                
                winPartyIds = Set(winRows.map { $0.party_id })
                lossPartyIds = Set(lossRows.map { $0.party_id })
            }
            
            let newParties = filteredPartiesChunk.compactMap { p -> Party? in
                guard let partyId = p.id else { return nil }
                
                // Avoid duplicates
                guard !loadedPartyIds.contains(partyId) else { return nil }
                
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
                // Track loaded party IDs
                for party in newParties {
                    if let partyId = party.id {
                        self.loadedPartyIds.insert(partyId)
                    }
                }
                
                if isInitialLoad || silentRefresh {
                    self.parties = newParties
                    self.wonPartyIds = winPartyIds
                    self.lostPartyIds = lossPartyIds
                    self.currentOffset = newParties.count
                } else {
                    // Append for pagination
                    self.parties.append(contentsOf: newParties)
                    self.currentOffset += newParties.count
                }
                
                // Check if there are more parties to load
                self.hasMoreParties = newParties.count == self.chunkSize
                
                if isInitialLoad { self.isLoading = false }
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error loading parties: \(error.localizedDescription)"
                if isInitialLoad { self.isLoading = false }
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
