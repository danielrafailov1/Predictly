import SwiftUI
import Supabase

struct PartyDetailsView: View {
    let party_code: String
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
    @State private var memberBetStatus: [String: Bool] = [:] // Track bet status for each member
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
    @State private var gameStatus: String = "waiting" // waiting, started, ended
    @State private var showConfirmOutcomeView = false
    @State private var showGameResultsView = false
    @State private var showStartGameConfirmation = false
    @State private var showEndGameConfirmation = false
    @State private var maxSelections: Int = 1
    
    // NEW: Timer/Contest specific properties
    @State private var timerDuration: Int = 0 // in seconds
    @State private var allowEarlyFinish: Bool = false
    @State private var contestUnit: String = ""
    @State private var contestTarget: Int = 0
    @State private var allowTies: Bool = false
    
    // NEW: Timer for auto-updating
    @State private var updateTimer: Timer?
    
    // NEW: States for bet warning
    @State private var showBetWarning = false
    @State private var playersWithoutBets: [String] = []
    
    // Action sheet states
    @State private var showActionSheet = false
    @State private var showInviteActionSheet = false
    
    // NEW: Member management states
    @State private var selectedMemberIndex: Int?
    @State private var showMemberActionSheet = false
    @State private var showKickConfirmation = false
    @State private var showPromoteConfirmation = false
    @State private var memberToKick: (userId: String, username: String)?
    @State private var memberToPromote: (userId: String, username: String)?
    
    // Computed property to check if current user is host
    private var isHost: Bool {
        return currentUserId == hostUserId
    }
    
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
                    customHeaderView
                    ScrollView {
                        VStack(spacing: 24) {
                            // Party Info Section
                            VStack(spacing: 16) {
                                hostCard
                                partyCodeCard
                                betTypeCard
                                // NEW: Show timer/contest specific info
                                if betType.lowercased() == "timer" || betType.lowercased() == "contest" {
                                    timerContestInfoCard
                                }
                                buyInAndPotCard
                                membersCard
                            }
                            
                            // Quick Actions Section
                            quickActionsSection
                            
                            // Main Actions Section
                            mainActionsSection
                        }
                        .padding(.bottom, 100) // Add padding for floating action button
                    }
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showActionSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true) // Hide the default back button
        .navigationDestination(isPresented: $showGameEventView) {
            if let game = selectedGame, let partyId = self.partyId, let userId = self.currentUserId, !partyBets.isEmpty {
                GameEventHostView(navPath: .constant(NavigationPath()), game: game, partyId: partyId, userId: userId, betType: .predefined, refreshCount: .constant(0), maxRefreshes: 0, party_code: party_code, userEmail: email, fixedEvents: partyBets)
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
                await fetchGameStatus()
                if let userEmail = sessionManager.userEmail {
                    profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
                }
            }
            // Start auto-update timer
            startAutoUpdate()
        }
        .onDisappear {
            // Stop auto-update timer when view disappears
            stopAutoUpdate()
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
            if let partyId = partyId, let userId = currentUserId {
                PlaceBetView(
                    partyId: partyId,
                    userId: userId,
                    partyName: partyName,
                    betPrompt: betPrompt,
                    betOptions: partyBets,
                    betTerms: betTerms,
                    maxSelections: maxSelections,
                    betType: betType,
                    timerDuration: timerDuration, // NEW: Pass timer duration
                    allowEarlyFinish: allowEarlyFinish, // NEW: Pass early finish setting
                    contestUnit: contestUnit, // NEW: Pass contest unit
                    contestTarget: contestTarget, // NEW: Pass contest target
                    allowTies: allowTies, // NEW: Pass allow ties setting
                    isEditing: hasPlacedBet
                )
            } else {
                Text("Unable to load bet information")
                    .foregroundColor(.red)
                    .onAppear {
                        print("Missing data - partyId: \(String(describing: partyId)), userId: \(String(describing: currentUserId)), partyBets: \(partyBets)")
                    }
            }
        }
        .navigationDestination(isPresented: $showConfirmOutcomeView) {
            if let partyId = partyId {
                ConfirmBetOutcomeView(
                    partyId: partyId,
                    partyName: partyName,
                    betOptions: partyBets,
                    betPrompt: betPrompt
                )
            }
        }
        .navigationDestination(isPresented: $showGameResultsView) {
            if let partyId = partyId {
                GameResultsView(partyId: partyId, partyName: partyName)
            }
        }
        .alert("Start Game", isPresented: $showStartGameConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Start") {
                Task {
                    await startGame()
                }
            }
        } message: {
            Text("Starting the game will disable all bet editing. Are you sure?")
        }
        .alert("End Game", isPresented: $showEndGameConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End") {
                Task {
                    await endGame()
                    showConfirmOutcomeView = true
                }
            }
        } message: {
            Text("Ready to end the game and confirm the bet outcome?")
        }
        // NEW: Bet warning alert
        .alert("Players Haven't Bet Yet", isPresented: $showBetWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Start Anyway") {
                Task {
                    await startGame()
                }
            }
        } message: {
            Text("The following players haven't placed their bets yet:\n\n\(playersWithoutBets.joined(separator: ", "))\n\nAre you sure you want to start the game?")
        }
        // NEW: Member management alerts
        .alert("Kick Member", isPresented: $showKickConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Kick", role: .destructive) {
                Task {
                    if let member = memberToKick {
                        await kickMember(userId: member.userId)
                    }
                }
            }
        } message: {
            if let member = memberToKick {
                Text("Are you sure you want to kick \(member.username) from the party? This action cannot be undone.")
            }
        }
        .alert("Promote to Host", isPresented: $showPromoteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Promote") {
                Task {
                    if let member = memberToPromote {
                        await promoteMemberToHost(userId: member.userId)
                    }
                }
            }
        } message: {
            if let member = memberToPromote {
                Text("Are you sure you want to promote \(member.username) to party host? You will become a regular member.")
            }
        }
        .confirmationDialog("More Options", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Party Chat") {
                showPartyChat = true
            }
            Button("Bet Type Info") {
                showBetTypeTutorial = true
            }
            Button("Invite Players") {
                showInviteActionSheet = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Invite Players", isPresented: $showInviteActionSheet, titleVisibility: .visible) {
            Button("Invite Friends") {
                showInviteFriends = true
            }
            Button("Invite Others") {
                showInviteOthers = true
            }
            Button("Cancel", role: .cancel) { }
        }
        // NEW: Member action sheet
        .confirmationDialog("Member Actions", isPresented: $showMemberActionSheet, titleVisibility: .visible) {
            if let index = selectedMemberIndex, index < memberUsernames.count {
                let username = memberUsernames[index]
                let userId = index < memberUserIds.count ? memberUserIds[index] : ""
                
                // Don't show actions for the host themselves
                if userId != hostUserId {
                    Button("Kick \(username)") {
                        memberToKick = (userId: userId, username: username)
                        showKickConfirmation = true
                    }
                    
                    Button("Promote \(username) to Host") {
                        memberToPromote = (userId: userId, username: username)
                        showPromoteConfirmation = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    // MARK: - Member Management Functions
    
    private func kickMember(userId: String) async {
        guard let partyId = partyId else { return }
        
        do {
            // Remove from Party Members table
            _ = try await supabaseClient
                .from("Party Members")
                .delete()
                .eq("party_id", value: Int(partyId))
                .eq("user_id", value: userId)
                .execute()
            
            // Also remove any bets this user has placed
            _ = try await supabaseClient
                .from("User Bets")
                .delete()
                .eq("party_id", value: Int(partyId))
                .eq("user_id", value: userId)
                .execute()
            
            // Remove from local arrays
            await MainActor.run {
                if let index = memberUserIds.firstIndex(of: userId) {
                    memberUserIds.remove(at: index)
                    if index < memberUsernames.count {
                        memberUsernames.remove(at: index)
                    }
                }
                memberBetStatus.removeValue(forKey: userId)
            }
            
            print("Successfully kicked member: \(userId)")
            
        } catch {
            print("Error kicking member: \(error)")
            await MainActor.run {
                errorMessage = "Failed to kick member: \(error.localizedDescription)"
            }
        }
    }
    
    private func promoteMemberToHost(userId: String) async {
        guard let partyId = partyId else { return }
        
        do {
            // Update the party's created_by field to the new host
            _ = try await supabaseClient
                .from("Parties")
                .update(["created_by": userId])
                .eq("id", value: Int(partyId))
                .execute()
            
            // Update local state
            await MainActor.run {
                hostUserId = userId
                if let index = memberUserIds.firstIndex(of: userId),
                   index < memberUsernames.count {
                    hostUsername = memberUsernames[index]
                }
            }
            
            print("Successfully promoted member to host: \(userId)")
            
        } catch {
            print("Error promoting member to host: \(error)")
            await MainActor.run {
                errorMessage = "Failed to promote member: \(error.localizedDescription)"
            }
        }
    }
    
    // NEW: Timer/Contest Info Card
    private var timerContestInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: betType.lowercased() == "timer" ? "timer" : "trophy.fill")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 24)
                Text("\(betType.capitalized) Details")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if betType.lowercased() == "timer" {
                    HStack {
                        Text("Duration:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(formatDuration(timerDuration))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Early Finish:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(allowEarlyFinish ? "Allowed" : "Not Allowed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(allowEarlyFinish ? .green : .red)
                    }
                } else if betType.lowercased() == "contest" {
                    HStack {
                        Text("Target:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text("\(contestTarget) \(contestUnit)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Ties:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(allowTies ? "Allowed" : "Not Allowed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(allowTies ? .green : .red)
                    }
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
    
    // NEW: Format duration helper
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    // MARK: - Custom Header with Back Button
    
    private var customHeaderView: some View {
        HStack {
            Button(action: {
                navigateToMyParties()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
            }
            .padding(.leading, 16)
            
            Spacer()
            
            Text(partyName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Spacer()
            
            // Invisible spacer to balance the back button
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                Text("My Parties")
                    .font(.system(size: 16, weight: .medium))
            }
            .opacity(0)
            .padding(.trailing, 16)
        }
        .padding(.top, 15)
        .onAppear { print("PartyDetailsView: loaded, partyName = \(partyName), partyId = \(String(describing: partyId))") }
    }
    
    // MARK: - Navigation Functions
    
    private func navigateToMyParties() {
        // Try to pop to root using UIKit navigation controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let navigationController = findNavigationController(from: window.rootViewController) {
            navigationController.popToRootViewController(animated: true)
        } else {
            // Fallback to dismiss if we can't find the navigation controller
            dismiss()
        }
    }
    
    private func findNavigationController(from viewController: UIViewController?) -> UINavigationController? {
        if let navigationController = viewController as? UINavigationController {
            return navigationController
        }
        
        if let tabBarController = viewController as? UITabBarController {
            return findNavigationController(from: tabBarController.selectedViewController)
        }
        
        for child in viewController?.children ?? [] {
            if let navigationController = findNavigationController(from: child) {
                return navigationController
            }
        }
        
        return nil
    }
    
    // MARK: - View Sections
    
    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Chat",
                color: .green
            ) {
                showPartyChat = true
            }
            
            QuickActionButton(
                icon: "person.crop.circle.badge.plus",
                title: "Invite",
                color: .blue
            ) {
                showInviteActionSheet = true
            }
            
            QuickActionButton(
                icon: "info.circle.fill",
                title: "Info",
                color: .orange
            ) {
                showBetTypeTutorial = true
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var mainActionsSection: some View {
        VStack(spacing: 16) {
            // All bet types can make/edit bets when game is waiting
            if gameStatus == "waiting" {
                makeBetButton
            }
            
            // Host-only game control buttons for all bet types
            if isHost {
                hostControlButtons
            }
            
            // Game Results button - Show for ALL users when game is ended
            if gameStatus == "ended" {
                gameResultsButton
            }
        }
        .padding(.horizontal, 24)
    }
    
    // Auto-update functions
    private func startAutoUpdate() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await updatePartyMembers()
                await updateMemberBetStatus()
            }
        }
    }
    
    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // Update only party members (lighter than full fetch)
    private func updatePartyMembers() async {
        guard let partyId = partyId else { return }
        
        do {
            // Get party members from Party Members table
            let membersResponse = try await supabaseClient
                .from("Party Members")
                .select("user_id")
                .eq("party_id", value: Int(partyId))
                .execute()
            
            struct MemberResult: Codable { let user_id: String }
            let members = try JSONDecoder().decode([MemberResult].self, from: membersResponse.data)
            var memberIds = members.map { $0.user_id }
            
            // Ensure host is included as a member
            if !hostUserId.isEmpty && !memberIds.contains(hostUserId) {
                memberIds.append(hostUserId)
            }
            
            // Only update if the member list has changed
            if memberIds != memberUserIds {
                await MainActor.run {
                    self.memberUserIds = memberIds
                }
                
                // Fetch usernames for new members
                await fetchUsernames()
            }
            
        } catch {
            print("Error updating party members: \(error)")
        }
    }
    
    // Update member bet status
    private func updateMemberBetStatus() async {
        guard let partyId = partyId, !memberUserIds.isEmpty else { return }
        
        do {
            let betResponse = try await supabaseClient
                .from("User Bets")
                .select("user_id")
                .eq("party_id", value: Int(partyId))
                .in("user_id", values: memberUserIds)
                .execute()
            
            struct BetResult: Codable { let user_id: String }
            let bets = try JSONDecoder().decode([BetResult].self, from: betResponse.data)
            let usersWithBets = Set(bets.map { $0.user_id })
            
            var newBetStatus: [String: Bool] = [:]
            for userId in memberUserIds {
                newBetStatus[userId] = usersWithBets.contains(userId)
            }
            
            await MainActor.run {
                self.memberBetStatus = newBetStatus
            }
            
        } catch {
            print("Error updating member bet status: \(error)")
        }
    }
    
    // NEW: Check if all players have placed bets
    private func checkAllPlayersBet() async -> Bool {
        guard let partyId = partyId, !memberUserIds.isEmpty else { return true }
        
        // Get usernames of players who haven't bet
        var playersWithoutBetsTemp: [String] = []
        
        for (index, userId) in memberUserIds.enumerated() {
            let hasBet = memberBetStatus[userId] ?? false
            if !hasBet {
                let username = index < memberUsernames.count ? memberUsernames[index] : userId
                playersWithoutBetsTemp.append(username)
            }
        }
        
        await MainActor.run {
            self.playersWithoutBets = playersWithoutBetsTemp
        }
        
        return playersWithoutBetsTemp.isEmpty
    }
    
    // MARK: - Computed Properties for Buttons
    
    private var makeBetButton: some View {
        Button(action: {
            showPlaceBetView = true
        }) {
            HStack {
                Image(systemName: hasPlacedBet ? "pencil.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(hasPlacedBet ? "Edit Bet" : "Make a Bet")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.orange.opacity(0.9))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private var hostControlButtons: some View {
        Group {
            switch gameStatus {
            case "waiting":
                startGameButton
            case "started":
                endGameButton
            case "ended":
                EmptyView()
            default:
                EmptyView()
            }
        }
    }
    
    private var startGameButton: some View {
        Button(action: {
            // Check if all players have bet before showing confirmation (for normal bets only)
            Task {
                if betType.lowercased() == "normal" {
                    let allPlayersBet = await checkAllPlayersBet()
                    if allPlayersBet {
                        await MainActor.run {
                            showStartGameConfirmation = true
                        }
                    } else {
                        await MainActor.run {
                            showBetWarning = true
                        }
                    }
                } else {
                    // For timer/contest bets, just start the game
                    await MainActor.run {
                        showStartGameConfirmation = true
                    }
                }
            }
        }) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Start Game")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green.opacity(0.9))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private var endGameButton: some View {
        Button(action: {
            showEndGameConfirmation = true
        }) {
            HStack {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("End Game")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.9))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private var gameResultsButton: some View {
        Button(action: {
            showGameResultsView = true
        }) {
            HStack {
                Image(systemName: "trophy.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Review Game Results")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.purple.opacity(0.9))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - View Components

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
                Text(party_code)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                Button(action: {
                    UIPasteboard.general.string = party_code
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
        case "normal": return "Normal Bet"
        case "timer": return "Timer Bet"
        case "contest": return "Contest Bet"
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
                HStack {
                    Text("Game Status:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(gameStatus.capitalized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(gameStatusColor(gameStatus))
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
    
    private func gameStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "waiting": return .yellow
        case "started": return .green
        case "ended": return .red
        default: return .white
        }
    }

    // NEW: Enhanced Members card with clickable member names for hosts
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
                    ForEach(Array(zip(memberUsernames.indices, memberUsernames)), id: \.0) { index, username in
                        let userId = index < memberUserIds.count ? memberUserIds[index] : ""
                        let hasBet = memberBetStatus[userId] ?? false
                        let isHostMember = userId == hostUserId
                        
                        HStack(spacing: 8) {
                            // Show crown icon for host
                            Image(systemName: isHostMember ? "crown.fill" : "person.fill")
                                .foregroundColor(isHostMember ? .yellow : .white.opacity(0.7))
                            
                            // Member name - clickable for hosts if it's not themselves
                            if isHost && !isHostMember {
                                Button(action: {
                                    selectedMemberIndex = index
                                    showMemberActionSheet = true
                                }) {
                                    Text(username)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                        .underline()
                                }
                            } else {
                                Text(username)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            // Host label
                            if isHostMember {
                                Text("(Host)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.yellow.opacity(0.8))
                                    .italic()
                            }
                            
                            Spacer()
                            
                            // Bet status indicator - only show for normal bets that aren't ended
                            if betType.lowercased() == "normal" && gameStatus != "ended" {
                                HStack(spacing: 4) {
                                    Image(systemName: hasBet ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(hasBet ? .green : .orange)
                                        .font(.system(size: 14))
                                    Text(hasBet ? "Bet Placed" : "No Bet")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(hasBet ? .green : .orange)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
                
                // Show instructions for hosts
                if isHost && memberUsernames.count > 1 {
                    Text("Tap member names to manage them")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .italic()
                        .padding(.top, 8)
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
    
    // Add this struct for UserBet at the top of your file
    struct UserBet: Codable {
        let id: Int?
        let created_at: String?
        let user_id: String
        let party_id: Int
        let bet_selection: String?
        let bet_events: [String]?
        let is_winner: Bool?
    }

    // Replace these functions in your PartyDetailsView:

    private func fetchGameStatus() async {
        guard let partyId = partyId else { return }
        
        do {
            let response = try await supabaseClient
                .from("Parties")
                .select("game_status")
                .eq("id", value: Int(partyId))
                .limit(1)
                .execute()
            
            struct GameStatusResult: Codable { let game_status: String? }
            let results = try JSONDecoder().decode([GameStatusResult].self, from: response.data)
            
            if let result = results.first {
                await MainActor.run {
                    self.gameStatus = result.game_status ?? "waiting"
                }
            }
        } catch {
            print("Error fetching game status: \(error)")
            // Default to waiting if there's an error
            await MainActor.run {
                self.gameStatus = "waiting"
            }
        }
    }

    private func startGame() async {
        guard let partyId = partyId else { return }
        
        do {
            _ = try await supabaseClient
                .from("Parties")
                .update(["game_status": "started"])
                .eq("id", value: Int(partyId))
                .execute()
            
            await MainActor.run {
                self.gameStatus = "started"
            }
        } catch {
            print("Error starting game: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to start game: \(error.localizedDescription)"
            }
        }
    }

    private func endGame() async {
        guard let partyId = partyId else { return }
        
        do {
            _ = try await supabaseClient
                .from("Parties")
                .update(["game_status": "ended"])
                .eq("id", value: Int(partyId))
                .execute()
            
            await MainActor.run {
                self.gameStatus = "ended"
            }
        } catch {
            print("Error ending game: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to end game: \(error.localizedDescription)"
            }
        }
    }

    private func checkUserBetStatus() async {
        guard let userId = currentUserId, let partyId = partyId else { return }
        
        do {
            // Check if a bet exists
            let betResponse = try await supabaseClient
                .from("User Bets")
                .select()
                .eq("user_id", value: userId)
                .eq("party_id", value: Int(partyId))
                .limit(1)
                .execute()
            
            let decoder = JSONDecoder()
            let bets = try decoder.decode([UserBet].self, from: betResponse.data)
            
            await MainActor.run {
                self.hasPlacedBet = !bets.isEmpty
            }
            
        } catch {
            print("Error checking user bet status: \(error)")
            // Default to no bet placed if there's an error
            await MainActor.run {
                self.hasPlacedBet = false
            }
        }
    }

    // Update the fetchPartyDetails function to include all timer/contest fields:
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
            
            print("DEBUG: Fetching party details for code: \(party_code)")
            // UPDATED: Include all timer/contest fields in the select query
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("id, created_by, party_name, bet_type, max_members, status, bet, terms, game_status, max_selections, timer_duration, allow_early_finish, contest_unit, contest_target, allow_ties")
                .eq("party_code", value: party_code)
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
                let game_status: String?
                let max_selections: Int?
                let timer_duration: Int?  // NEW
                let allow_early_finish: Bool?  // NEW
                let contest_unit: String?  // NEW
                let contest_target: Int?  // NEW
                let allow_ties: Bool?  // NEW
            }
            
            let partyArray = try decoder.decode([PartyResult].self, from: partyResponse.data)
            print("DEBUG: Number of parties returned for code \(party_code): \(partyArray.count)")
            
            if partyArray.count > 1 {
                print("❌ Duplicate party_code detected in DB! Code:", party_code)
                await MainActor.run {
                    self.errorMessage = "Error: Duplicate party codes found for this code. Please contact support."
                    self.isLoading = false
                }
                return
            }
            
            if partyArray.isEmpty {
                print("❌ No party found for code:", party_code)
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
                self.gameStatus = partyResult.game_status ?? "waiting"
                self.maxSelections = partyResult.max_selections ?? 1
                
                // NEW: Set timer/contest specific properties
                self.timerDuration = partyResult.timer_duration ?? 0
                self.allowEarlyFinish = partyResult.allow_early_finish ?? false
                self.contestUnit = partyResult.contest_unit ?? ""
                self.contestTarget = partyResult.contest_target ?? 0
                self.allowTies = partyResult.allow_ties ?? false
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
            
            // Fetch initial member bet status
            await updateMemberBetStatus()
            
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

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.8))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
    }
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
                        Text("Normal Bet:")
                            .font(.headline)
                        Text("Bet on anything you can imagine! Choose from a list of AI-generated bets, options, and terms, or make your own. ")
                        
                        Text("Timed Bet:")
                            .font(.headline)
                        Text("Bet on a task or event that must be completed within a set amount of time to win. Examples include but are not limited to: ")
                        VStack(alignment: .leading, spacing: 5) {
                            Text("1. **Complete the Obstacle Course** – Can you finish the course within 10 minutes?")
                            Text("2. **Complete a Puzzle** – How fast can you finish a 100-piece jigsaw puzzle?")
                            Text("3. **Beat the Timer** – Complete a challenge in under 5 minutes to win!")
                            Text("4. **Cooking Challenge** – Can you cook a specific meal within 20 minutes?")
                            Text("5. **Finish a Workout** – Can you finish 50 push-ups in less than 2 minutes?")
                            Text("6. **Reading Challenge** – Read 5 pages of a book in under 5 minutes!")
                            Text("7. **Trivia Challenge** – Answer 10 questions in under 2 minutes!")
                            Text("8. **Solve a Riddle** – Can you solve the riddle in less than 30 seconds?")
                            Text("9. **Time to Complete a Game Level** – Finish a video game level in under 3 minutes.")
                            Text("10. **Complete a Task** – Can you write 100 words in 1 minute?")
                            Text("11. **Fitness Challenge** – Run 1 mile in less than 8 minutes.")
                            Text("12. **Time to Cook a Dish** – Make the best omelette in under 10 minutes.")
                            Text("13. **Art Challenge** – Draw a picture in 10 minutes and submit for review.")
                            Text("14. **Video Editing Challenge** – Edit a short video within 15 minutes.")
                            Text("15. **Trivia Speed Test** – Can you get 5 trivia questions correct in under 1 minute?")
                            Text("16. **Clean Your Room** – Can you clean your room within 20 minutes?")
                            Text("17. **Writing Challenge** – Write a 200-word essay in under 10 minutes.")
                            Text("18. **Memory Challenge** – Memorize a 10-item list in under 1 minute.")
                            Text("19. **Crafting Challenge** – Create a paper airplane in under 2 minutes and see how far it flies.")
                        }
                        
                        Text("Contest Bet:")
                            .font(.headline)
                        Text("A contest where participants race against each other to see who can complete a task the fastest. Examples include but are not limited to: ")
                        VStack(alignment: .leading, spacing: 5) {
                            Text("1. **Race to Finish the Puzzle** – Who can finish a 100-piece puzzle the fastest?")
                            Text("2. **Who Can Cook the Fastest** – Who can cook the best dish in under 30 minutes?")
                            Text("3. **Head-to-Head Workout Challenge** – Who can do 50 push-ups faster?")
                            Text("4. **Speed Reading** – Who can read and comprehend more pages in 5 minutes?")
                            Text("5. **Race to Finish the Game** – Who can beat the first level of a game faster?")
                            Text("6. **Speed Trivia** – Who can answer 10 questions the fastest?")
                            Text("7. **Fastest Drawing Challenge** – Who can draw a recognizable picture the fastest?")
                            Text("8. **Cooking Contest** – Who can make the tastiest dish in the shortest amount of time?")
                            Text("9. **Speed Problem Solving** – Who can solve a series of math problems faster?")
                            Text("10. **Fitness Race** – Who can run a mile faster?")
                            Text("11. **Fastest Scavenger Hunt** – Who can find and bring back 5 items the fastest?")
                            Text("12. **Memory Challenge** – Who can memorize a list of 10 items the fastest?")
                            Text("13. **Speed Word Game** – Who can come up with the most words in 2 minutes?")
                            Text("14. **Fastest to Clean** – Who can clean a room the fastest?")
                            Text("15. **Art Race** – Who can draw the best picture in 5 minutes?")
                            Text("16. **Speed to Write** – Who can write a 100-word essay the fastest?")
                            Text("17. **Fitness Challenge Race** – Who can do 100 push-ups the fastest?")
                            Text("18. **Dance Battle** – Who can do the best dance move in 1 minute?")
                            Text("19. **Creative Speed Challenge** – Who can come up with the most creative idea in 10 minutes?")
                        }
                    }
                    .padding(.bottom, 4)
                    
                    Text("Ask your friends if you're unsure which bet type to choose!")
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
