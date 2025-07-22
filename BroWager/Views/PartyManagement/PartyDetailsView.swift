import SwiftUI
import Supabase

struct PartyDetailsView: View {
    let partyCode: String
    let email: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var partyName: String = ""
    @State private var hostUserId: String = ""
    @State private var gameId: String = ""
    @State private var partyId: Int64?
    @State private var betQuantity: Int?
    @State private var potBalance: Int?
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
    @EnvironmentObject var sessionManager: SessionManager
    @State private var partyBets: [String] = []
    @State private var showGameEventSheet = false
    @State private var partyEvents: [String] = []
    @State private var showPartyChat = false
    @State private var previousBet: [String]? = nil
    @State private var showBetTypeTutorial = false
    @State private var betType: String = ""
    
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
                }
                .onAppear { print("PartyDetailsView: errorMessage = \(error)") }
            } else {
                VStack(spacing: 0) {
                    headerView
                    ScrollView {
                        VStack(spacing: 32) {
                            hostCard
                            partyCodeCard
                            gameCard
                            betTypeCard
                            buyInAndPotCard
                            membersCard
                            // ...other cards...
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
                                Task { await fetchPartyEventsAndShowBet() }
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
            Text("Game event view is no longer available.")
        }
        .onAppear {
            print("PartyDetailsView: email = \(email)")
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
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: .constant(NavigationPath()), email: "")
        }
        .sheet(isPresented: $showGameEventSheet) {
            Text("Game event view is no longer available.")
        }
        .sheet(isPresented: $showPartyChat) {
            if let partyId = partyId {
                PartyChatView(partyId: partyId, partyName: partyName)
            }
        }
        .sheet(isPresented: $showBetTypeTutorial) {
            BetTypeTutorialSheet()
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

    private var gameCard: some View {
        partyInfoCard(
            icon: "gamecontroller.fill",
            title: "Game",
            value: homeTeam.isEmpty && awayTeam.isEmpty ? "Game not found" : "\(homeTeam) vs \(awayTeam)"
        )
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
        case "normal": return "Normal Bet"
        case "timed": return "Timed Bet"
        case "contest": return "Contest Bet"
        default: return type.capitalized
        }
    }

    private var buyInAndPotCard: some View {
        Group {
            if let betQuantity = betQuantity, let potBalance = potBalance {
                HStack {
                    partyInfoCard(
                        icon: "dollarsign.circle",
                        title: "Buy-In",
                        value: "\(betQuantity) Tokens"
                    )
                    partyInfoCard(
                        icon: "trophy.fill",
                        title: "Prize Pot",
                        value: "\(potBalance) Tokens"
                    )
                }
            }
        }
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
        isLoading = true
        errorMessage = nil
        do {
            // Fetch user_id for the current user
            let userResponse = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            let decoder = JSONDecoder()
            struct UserIdResult: Codable { let user_id: String }
            let userIdResults = try decoder.decode([UserIdResult].self, from: userResponse.data)
            guard let userIdResult = userIdResults.first else {
                await MainActor.run {
                    self.errorMessage = "User not found"
                    self.isLoading = false
                }
                return
            }
            let userId = userIdResult.user_id
            await MainActor.run { self.currentUserId = userId }
            
            print("DEBUG: Fetching party details for code: \(partyCode)")
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("id, game_id, created_by, party_name, bet_quantity, pot_balance, bet_type")
                .eq("party_code", value: partyCode)
                .execute()
            print("DEBUG: Party fetch succeeded")
            let rawPartyData = String(data: partyResponse.data, encoding: .utf8) ?? "No data"
            print("DEBUG: Raw party response data: \(rawPartyData)")
            if let json = try? JSONSerialization.jsonObject(with: partyResponse.data, options: []),
               let array = json as? [[String: Any]] {
                print("DEBUG: Full rows returned for party_code \(partyCode):")
                for (idx, row) in array.enumerated() {
                    print("  Row \(idx + 1):", row)
                }
            } else {
                print("DEBUG: Could not parse rows as array of dictionaries.")
            }
            struct PartyResult: Codable {
                let id: Int64?
                let game_id: Int64?
                let created_by: String?
                let party_name: String?
                let bet_quantity: Int?
                let pot_balance: Int?
                let bet_type: String? // Optional for future-proofing
                // Add more optional fields here as needed
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
                self.gameId = String(partyResult.game_id ?? 0)
                self.betQuantity = partyResult.bet_quantity
                self.potBalance = partyResult.pot_balance
                self.betType = partyResult.bet_type ?? ""
            }
            
            // 3. Get party members from Party Members table
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
            
            // Fetch game info for display
            do {
                let gameIdInt = Int(partyResult.game_id ?? 0)
                let gameResponse = try await supabaseClient
                    .from("Game")
                    .select("home_team, away_team")
                    .eq("id", value: gameIdInt)
                    .limit(1)
                    .execute()
                struct GameTeams: Codable {
                    let home_team: String
                    let away_team: String
                }
                let gameTeamsArray = try decoder.decode([GameTeams].self, from: gameResponse.data)
                if let gameTeams = gameTeamsArray.first {
                    await MainActor.run {
                        self.homeTeam = gameTeams.home_team
                        self.awayTeam = gameTeams.away_team
                    }
                }
            } catch {
                print("❌ Error fetching teams for game: \(error)")
            }
            
            // Fetch usernames for host and members
            do {
                var userIds = memberUserIds
                userIds.append(hostUserId)
                let response = try await supabaseClient
                    .from("Username")
                    .select("user_id, username")
                    .in("user_id", values: userIds)
                    .execute()
                struct UsernameRow: Codable { let user_id: String; let username: String }
                let usernames = try decoder.decode([UsernameRow].self, from: response.data)
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
    
    private func fetchGameAndNavigate() async {
        // If we don't have game details, fetch them first.
        if selectedGame == nil {
            await fetchGameForStatusCheck()
        }
        // Now that we're sure we have the game, fetch the bets and navigate.
        if let partyId = self.partyId {
            if let bets = await fetchPartyBets(partyId: partyId) {
                await MainActor.run {
                    self.partyBets = bets
                    self.showGameEventView = true
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "No bets found for this party."
                }
            }
        }
    }
    
    private func checkUserBetStatus() async {
        guard let userId = currentUserId, let partyId = partyId, !gameId.isEmpty else { return }
        
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

            // Ensure we have game details to check the date
            if selectedGame == nil {
                await fetchGameForStatusCheck()
            }

            if let game = selectedGame {
                let formatter = ISO8601DateFormatter()
                if let gameDate = formatter.date(from: game.date) {
                    await MainActor.run {
                        self.isGameFinished = gameDate < Date()
                    }
                }
            }
            
        } catch {
            print("Error checking user bet status: \(error)")
        }
    }
    
    private func fetchGameForStatusCheck() async {
        guard selectedGame == nil, let gameIdInt = Int(gameId) else { return }
        do {
            let response = try await supabaseClient
                .from("Game")
                .select("id, home_team, away_team, date")
                .eq("id", value: gameIdInt)
                .limit(1)
                .execute()
            
            struct GameRow: Codable {
                let id: Int
                let home_team: String
                let away_team: String
                let date: String
            }
            let gameRow = try JSONDecoder().decode(GameRow.self, from: response.data)

            let baseballGame = BaseballGame(
                id: gameRow.id,
                home_team_name: gameRow.home_team,
                away_team_name: gameRow.away_team,
                date: gameRow.date
            )
            await MainActor.run {
                self.selectedGame = baseballGame
            }
        } catch {
            print("❌ Error fetching game for status check: \(error)")
        }
    }
    
    private func checkBetResults() async {
        guard let userId = currentUserId, let partyId = partyId, let game = selectedGame else { return }
        
        struct UserBetEvents: Codable {
            let bet_events: [String]
        }
        do {
            // 1. Fetch the user's bets
            let betResponse: [UserBetEvents] = try await supabaseClient
                .from("User Bets")
                .select("bet_events")
                .eq("user_id", value: userId)
                .eq("party_id", value: Int(partyId))
                .limit(1)
                .execute()
                .value
            
            print("DEBUG: betResponse = \(betResponse)")
            
            guard let userBet = betResponse.first else {
                await MainActor.run {
                    self.errorMessage = "No bet found for this party. Please make a bet first."
                }
                print("DEBUG: No bet found for userId=\(userId), partyId=\(partyId)")
                return
            }
            print("DEBUG: userBet.bet_events = \(userBet.bet_events)")
            // 2. Create the prompt for Gemini
            let prompt = """
            You are a sports game fact-checker. For the baseball game between \(game.home_team_name) and \(game.away_team_name) that occurred on \(game.date), please analyze the following list of predicted events. Return a JSON object with a single key \"correct_bets\" which holds an array of strings. This array should contain ONLY the predicted events from the list that actually happened.

            List of predicted events:
            \(userBet.bet_events.joined(separator: "\n"))
            """

            // 3. Call Gemini API
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=AIzaSyBPjz5MsImnnmKvyltj6X6h7E-JqVufe4E") else {
                // Replace YOUR_GEMINI_API_KEY with your actual key
                self.errorMessage = "Invalid Gemini API URL"
                return
            }
            
            let requestBody: [String: Any] = [
                "contents": [["parts": [["text": prompt]]]],
                "generationConfig": ["response_mime_type": "application/json"]
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            print("DEBUG: Gemini raw response = \(String(data: data, encoding: .utf8) ?? "nil")")
            // 4. Parse response and update score
            struct GeminiResponse: Decodable {
                struct Candidate: Decodable {
                    struct Content: Decodable {
                        struct Part: Decodable {
                            let text: String
                        }
                        let parts: [Part]
                    }
                    let content: Content
                }
                let candidates: [Candidate]
            }

            let responseText = try JSONDecoder().decode(GeminiResponse.self, from: data).candidates.first?.content.parts.first?.text ?? ""
            print("DEBUG: Gemini responseText = \(responseText)")
            struct ResultPayload: Decodable {
                let correct_bets: [String]
            }
            
            let resultData = Data(responseText.utf8)
            let finalResult = try JSONDecoder().decode(ResultPayload.self, from: resultData)
            
            let correctBetsArray = finalResult.correct_bets
            let score = correctBetsArray.count
            
            // 5. Update the UserBets table
            try await supabaseClient
                .from("User Bets")
                .update(["score": score])
                .eq("user_id", value: userId)
                .eq("party_id", value: Int(partyId))
                .execute()
                
            // 6. Update the UI
            await MainActor.run {
                self.score = score
                self.correctBets = correctBetsArray
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to check results: \(error.localizedDescription)"
            }
            print("DEBUG: Error in checkBetResults: \(error)")
        }
    }
    
    // Fetch bets for this party from the Parties table (events column)
    private func fetchPartyBets(partyId: Int64) async -> [String]? {
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("events")
                .eq("id", value: Int(partyId))
                .limit(1)
                .execute()
            struct EventsRow: Decodable { let events: [String]? }
            let row = try JSONDecoder().decode([EventsRow].self, from: response.data)
            return row.first?.events
        } catch {
            print("Error fetching events from Parties table: \(error)")
            return nil
        }
    }
    
    private func fetchPartyEventsAndShowBet(editing: Bool = false) async {
        guard let partyId = partyId, let userId = currentUserId else { return }
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("events")
                .eq("id", value: Int(partyId))
                .single()
                .execute()
            struct EventsRow: Decodable { let events: [String] }
            let decoder = JSONDecoder()
            let row = try decoder.decode(EventsRow.self, from: response.data)
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
                partyEvents = row.events
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
                        Text("• Normal Bets:")
                            .font(.headline)
                        Text("A standard bet with no time constraints.")
                        Text("• Timed Bets:")
                            .font(.headline)
                        Text("A bet that must be completed within a certain time.")
                        Text("• Contest Bets:")
                            .font(.headline)
                        Text("A competitive bet with multiple participants.")
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
