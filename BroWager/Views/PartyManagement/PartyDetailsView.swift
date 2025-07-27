import SwiftUI
import Supabase

struct PartyDetailsView: View {
    let partyCode: String
    let email: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var partyName: String = ""
    @State private var hostUserId: String = ""
    @State private var partyId: Int64?
    @State private var maxMembers: Int64 = 10
    @State private var status: String = ""
    @State private var memberUserIds: [String] = []
    @State private var showCopied = false
    @State private var showGameEventView = false
    @State private var selectedGame: BaseballGame? = nil
    @State private var homeTeam: String = ""
    @State private var awayTeam: String = ""
    @State private var hostUsername: String = ""
    @State private var memberUsernames: [String] = []
    @State private var showInviteFriends = false
    @State private var showInviteOthers = false
    @State private var currentUserId: String? = nil
    @State private var hasPlacedBet = false
    @State private var isGameFinished = false
    @State private var score: Int? = nil
    @State private var correctBets: [String]? = nil
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @State private var partyBets: [String] = []
    @State private var showGameEventSheet = false
    @State private var partyEvents: [String] = []
    @State private var showPartyChat = false
    @State private var previousBet: [String]? = nil
    @State private var draftTeamWinner: String? = nil
    @State private var draftTeamWinningTeam: [String]? = nil
    @State private var showBetTypeTutorial = false
    @State private var betType: String = ""
    @State private var showPlaceBetView = false
    @State private var betPrompt: String = ""
    @State private var betTerms: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.red.opacity(0.05)
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
                    .onAppear { print("PartyDetailsView: isLoading = true") }
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
                    
                    Button("Retry") {
                        Task {
                            await fetchPartyDetails()
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .onAppear { print("PartyDetailsView: errorMessage = \(error)") }
            } else {
                VStack(spacing: 0) {
                    headerView
                    ScrollView {
                        VStack(spacing: 32) {
                            hostCard
                            partyCodeCard
                            betTypeCard
                            buyInAndPotCard
                            membersCard
                            VStack(spacing: 16) {
                                VStack(spacing: 18) {
                                    Button(action: { showInviteFriends = true }) {
                                        HStack {
                                            Image(systemName: "person.crop.circle.badge.plus")
                                            Text("Invite Friends")
                                        }
                                        .font(.system(size: 18, weight: .semibold))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue.opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    Button(action: { showPartyChat = true }) {
                                        HStack {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                            Text("Party Chat")
                                        }
                                        .font(.system(size: 18, weight: .semibold))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.green.opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                    }
                                    Button(action: { showBetTypeTutorial = true }) {
                                        HStack {
                                            Image(systemName: "info.circle.fill")
                                            Text("Bet Type Info")
                                        }
                                        .font(.system(size: 18, weight: .semibold))
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.yellow.opacity(0.85))
                                        .foregroundColor(.black)
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                            }
                            // Add Make a Bet button at the bottom
                            Button(action: {
                                showPlaceBetView = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Make a Bet")
                                }
                                .font(.system(size: 20, weight: .bold))
                                .padding(.vertical, 12)
                                .padding(.horizontal, 32)
                                .background(Color.orange.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .padding(.top, 18)
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showGameEventView) {
            if let game = selectedGame, let partyId = self.partyId, let userId = self.currentUserId, !partyBets.isEmpty {
                GameEventHostView(navPath: .constant(NavigationPath()), game: game, partyId: partyId, userId: userId, betType: .predefined, refreshCount: .constant(0), maxRefreshes: 0, partyCode: partyCode, userEmail: email, fixedEvents: partyBets)
                    .onAppear { print("PartyDetailsView: Navigating to GameEventHostView with game = \(game), partyId = \(partyId), userId = \(userId)") }
            } else {
                Text("Missing game, user, or events data.")
                    .foregroundColor(.yellow)
                    .onAppear { print("PartyDetailsView: Navigation destination missing required data") }
            }
        }
        .onAppear {
            print("PartyDetailsView: email = \(email)")
            print("PartyDetailsView: sessionManager.userEmail = \(sessionManager.userEmail ?? "nil")")
            print("PartyDetailsView: onAppear called")
            Task {
                await fetchPartyDetails()
                await checkUserBetStatus()
                if let userEmail = sessionManager.userEmail {
                    profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
                }
            }
        }
        .sheet(isPresented: $showInviteFriends) {
            if let partyId = partyId, let userId = currentUserId {
                InviteFriendsToPartyView(partyId: partyId, inviterUserId: userId)
                    .environment(\.supabaseClient, supabaseClient)
            }
        }
        .sheet(isPresented: $showInviteOthers) {
            if let partyId = partyId, let userId = currentUserId {
                InviteOthersToPartyView(partyId: partyId, inviterUserId: userId)
                    .environment(\.supabaseClient, supabaseClient)
            }
        }
        .sheet(isPresented: $showPartyChat) {
            if let partyId = partyId {
                PartyChatView(partyId: partyId, partyName: partyName)
            }
        }
        .sheet(isPresented: $showBetTypeTutorial) {
            BetTypeTutorialSheet()
        }
        .navigationDestination(isPresented: $showPlaceBetView) {
            if let partyId = partyId, let userId = currentUserId, !partyBets.isEmpty {
                PlaceBetView(
                    partyId: partyId,
                    userId: userId,
                    partyName: partyName,
                    betPrompt: betPrompt,
                    betOptions: partyBets,
                    betTerms: betTerms
                )
            } else {
                Text("Unable to load bet information")
                    .foregroundColor(.red)
                    .onAppear {
                        print("Missing data - partyId: \(String(describing: partyId)), userId: \(String(describing: currentUserId)), partyBets: \(partyBets)")
                    }
            }
        }
    }
    
    private var headerView: some View {
        Text(partyName)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.top, 15)
            .onAppear { print("PartyDetailsView: loaded, partyName = \(partyName), partyId = \(String(describing: partyId))") }
    }

    private var hostCard: some View {
        partyInfoCard(
            icon: "person.crop.circle.fill",
            title: "Host",
            value: hostUsername.isEmpty ? hostUserId : hostUsername
        )
    }

    private var partyCodeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "number.square")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24)
                Text("Party Code")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            HStack(spacing: 12) {
                Text(partyCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                Button(action: {
                    UIPasteboard.general.string = partyCode
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation { showCopied = false }
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .semibold))
                }
                if showCopied {
                    Text("Copied!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var betTypeCard: some View {
        partyInfoCard(
            icon: "questionmark.circle.fill",
            title: "Bet Type",
            value: betTypeDisplayName(betType)
        )
    }

    private func betTypeDisplayName(_ type: String) -> String {
        switch type.lowercased() {
        case "predefined": return "Predefined Bet"
        case "draftteam": return "Draft Team Bet"
        case "randomplayer": return "Random Player Bet"
        case "custom": return "Custom Bet"
        case "normal": return "Normal Bet"
        default: return type.capitalized
        }
    }

    private var buyInAndPotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24)
                Text("Party Info")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Max Members:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(memberUserIds.count)/\(maxMembers)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                HStack {
                    Text("Status:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(status.capitalized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(status.lowercased() == "open" ? .green : .orange)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24)
                Text("Party Members")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            if memberUsernames.isEmpty {
                Text("No members yet.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 8)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(memberUsernames, id: \.self) { username in
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white.opacity(0.7))
                            Text(username)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    private func partyInfoCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
    
    private func fetchPartyDetails() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Use the email parameter or fall back to sessionManager
            let userEmail = !email.isEmpty ? email : (sessionManager.userEmail ?? "")
            
            guard !userEmail.isEmpty else {
                await MainActor.run {
                    self.errorMessage = "No user email available"
                    self.isLoading = false
                }
                return
            }
            
            print("DEBUG: Using email for lookup: \(userEmail)")
            
            // Fetch user_id for the current user
            let userResponse = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: userEmail)
                .limit(1)
                .execute()
            
            let decoder = JSONDecoder()
            struct UserIdResult: Codable { let user_id: String }
            let userIdResults = try decoder.decode([UserIdResult].self, from: userResponse.data)
            
            guard let userIdResult = userIdResults.first else {
                print("DEBUG: No user found for email: \(userEmail)")
                await MainActor.run {
                    self.errorMessage = "User not found for email: \(userEmail)"
                    self.isLoading = false
                }
                return
            }
            
            let userId = userIdResult.user_id
            print("DEBUG: Found userId: \(userId) for email: \(userEmail)")
            await MainActor.run { self.currentUserId = userId }
            
            print("DEBUG: Fetching party details for code: \(partyCode)")
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("id, created_by, party_name, bet_type, max_members, status, bet, terms")
                .eq("party_code", value: partyCode)
                .execute()
            
            print("DEBUG: Party fetch succeeded")
            let rawPartyData = String(data: partyResponse.data, encoding: .utf8) ?? "No data"
            print("DEBUG: Raw party response data: \(rawPartyData)")
            
            struct PartyResult: Codable {
                let id: Int64?
                let created_by: String?
                let party_name: String?
                let bet_type: String?
                let max_members: Int64?
                let status: String?
                let bet: String?
                let terms: String?
            }
            
            let partyArray = try decoder.decode([PartyResult].self, from: partyResponse.data)
            print("DEBUG: Number of parties returned for code \(partyCode): \(partyArray.count)")
            
            if partyArray.count > 1 {
                print("❌ Duplicate party_code detected in DB! Code:", partyCode)
                await MainActor.run {
                    self.errorMessage = "Error: Duplicate party codes found for this code. Please contact support."
                    self.isLoading = false
                }
                return
            }
            
            if partyArray.isEmpty {
                print("❌ No party found for code:", partyCode)
                await MainActor.run {
                    self.errorMessage = "No party found for this code."
                    self.isLoading = false
                }
                return
            }
            
            let partyResult = partyArray[0]
            await MainActor.run {
                self.partyId = partyResult.id
                self.partyName = partyResult.party_name ?? ""
                self.hostUserId = partyResult.created_by ?? ""
                self.betType = partyResult.bet_type ?? ""
                self.maxMembers = partyResult.max_members ?? 10
                self.status = partyResult.status ?? "open"
                self.betPrompt = partyResult.bet ?? ""
                self.betTerms = partyResult.terms ?? ""
            }
            
            // Get party members from Party Members table
            let membersResponse = try await supabaseClient
                .from("Party Members")
                .select("user_id")
                .eq("party_id", value: Int(partyResult.id ?? 0))
                .execute()
            
            print("DEBUG: Raw members response data: \(String(data: membersResponse.data, encoding: .utf8) ?? "No data")")
            struct MemberResult: Codable { let user_id: String }
            let members = try decoder.decode([MemberResult].self, from: membersResponse.data)
            var memberIds = members.map { $0.user_id }
            
            // Ensure host is included as a member
            if let hostId = partyResult.created_by, !memberIds.contains(hostId) {
                memberIds.append(hostId)
            }
            
            print("DEBUG: Member user_ids for party_id \(partyResult.id ?? 0): \(memberIds)")
            await MainActor.run {
                self.memberUserIds = memberIds
                self.isLoading = false
            }
            
            // Fetch usernames for host and members
            await fetchUsernames()
            
            // Fetch the party bets after fetching party details
            if let partyId = self.partyId {
                if let bets = await fetchPartyBets(partyId: partyId) {
                    await MainActor.run { self.partyBets = bets }
                }
            }
            
        } catch {
            print("❌ Error fetching party details: \(error)")
            await MainActor.run {
                self.errorMessage = "Error loading party details: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchUsernames() async {
        do {
            var userIds = memberUserIds
            if !hostUserId.isEmpty {
                userIds.append(hostUserId)
            }
            
            guard !userIds.isEmpty else { return }
            
            let response = try await supabaseClient
                .from("Username")
                .select("user_id, username")
                .in("user_id", values: userIds)
                .execute()
            
            struct UsernameRow: Codable { let user_id: String; let username: String }
            let usernames = try JSONDecoder().decode([UsernameRow].self, from: response.data)
            let userIdToUsername = Dictionary(uniqueKeysWithValues: usernames.map { ($0.user_id, $0.username) })
            
            print("DEBUG: Usernames fetched for memberUserIds: \(self.memberUserIds)")
            print("DEBUG: userIdToUsername map: \(userIdToUsername)")
            
            await MainActor.run {
                self.hostUsername = userIdToUsername[self.hostUserId] ?? self.hostUserId
                self.memberUsernames = self.memberUserIds.compactMap { userIdToUsername[$0] }
            }
        } catch {
            print("❌ Error fetching usernames: \(error)")
        }
    }
    
    private func checkUserBetStatus() async {
        guard let userId = currentUserId, let partyId = partyId else { return }
        
        do {
            // Check if a bet exists
            let betResponse: [UserBet] = try await supabaseClient
                .from("User Bets")
                .select()
                .eq("user_id", value: userId)
                .eq("party_id", value: Int(partyId))
                .limit(1)
                .execute()
                .value
            
            await MainActor.run {
                self.hasPlacedBet = !betResponse.isEmpty
            }
            
        } catch {
            print("Error checking user bet status: \(error)")
        }
    }
    
    // Fetch bets for this party from the Parties table (options column)
    private func fetchPartyBets(partyId: Int64) async -> [String]? {
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("options")
                .eq("id", value: Int(partyId))
                .limit(1)
                .execute()
            struct OptionsRow: Decodable { let options: [String]? }
            let row = try JSONDecoder().decode([OptionsRow].self, from: response.data)
            return row.first?.options
        } catch {
            print("Error fetching options from Parties table: \(error)")
            return nil
        }
    }
    
    private func fetchPartyEventsAndShowBet(editing: Bool = false) async {
        guard let partyId = partyId, let userId = currentUserId else { return }
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("options")
                .eq("id", value: Int(partyId))
                .single()
                .execute()
            struct OptionsRow: Decodable { let options: [String] }
            let decoder = JSONDecoder()
            let row = try decoder.decode(OptionsRow.self, from: response.data)
            var prevBet: [String]? = nil
            if editing {
                let betResponse = try await supabaseClient
                    .from("User Bets")
                    .select("bet_events")
                    .eq("user_id", value: userId)
                    .eq("party_id", value: Int(partyId))
                    .limit(1)
                    .execute()
                struct UserBetEvents: Codable { let bet_events: [String] }
                let bets = try decoder.decode([UserBetEvents].self, from: betResponse.data)
                prevBet = bets.first?.bet_events
            }
            await MainActor.run {
                partyEvents = row.options
                previousBet = prevBet
                showGameEventSheet = false // reset
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showGameEventSheet = true
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch party events: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    PartyDetailsView(partyCode: "ABC123", email: "test@example.com")
        .environmentObject(SessionManager(supabaseClient: SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "public-anon-key"
        )))
}

struct BetTypeTutorialSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Bet Type System Tutorial")
                        .font(.title2).bold()
                        .padding(.bottom, 8)
                    Group {
                        Text("• Predefined Bets:")
                            .font(.headline)
                        Text("Choose from a list of preset bets for the game. These are quick, common bets like 'Who will win?' or 'Will there be a home run?'.")
                        Text("• Draft Team:")
                            .font(.headline)
                        Text("Each player drafts a team from the available players. Your team's performance determines your bet outcome.")
                        Text("• Random Player:")
                            .font(.headline)
                        Text("A player is randomly assigned to you. Your bet is based on that player's performance.")
                        Text("• Custom Bet:")
                            .font(.headline)
                        Text("Create your own bet with custom conditions and outcomes. Great for creative or group-specific bets.")
                        Text("• Normal Bet:")
                            .font(.headline)
                        Text("Create a custom bet with multiple options that players can choose from.")
                    }
                    .padding(.bottom, 4)
                    Text("Ask your host if you're unsure which bet type to choose!")
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.top, 12)
                }
                .padding()
            }
            .navigationTitle("Bet Type Info")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
