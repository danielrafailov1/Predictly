import SwiftUI
import Supabase

struct PlaceBetView: View {
    let partyId: Int64
    let userId: String
    let partyName: String
    let betPrompt: String
    let betOptions: [String]
    let betTerms: String
    let maxSelections: Int
    let betType: String  // NEW
    let timerDuration: Int  // NEW: Duration in seconds
    let allowEarlyFinish: Bool  // NEW
    let contestUnit: String  // NEW
    let contestTarget: Int  // NEW
    let allowTies: Bool  // NEW
    let isEditing: Bool
    
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOptions: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var existingBetId: Int64? = nil
    
    // NEW: Timer/Contest specific states
    @State private var timeRemaining: Int = 0
    @State private var timerRunning = false
    @State private var timer: Timer?
    @State private var hasTimerStarted = false
    @State private var isTimerFinished = false
    @State private var startTime: Date?
    @State private var endTime: Date?
    
    // NEW: Contest specific states
    @State private var contestScore: Int = 0
    @State private var contestStarted = false
    @State private var contestFinished = false
    @State private var elapsedTime: Int = 0
    @State private var elapsedTimer: Timer?
    
    private var isTimerBet: Bool {
        let normalizedBetType = betType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        print("🔍 Checking if timer bet - original: '\(betType)', normalized: '\(normalizedBetType)'")
        return normalizedBetType == "timed"
    }

    private var isContestBet: Bool {
        let normalizedBetType = betType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedBetType == "contest"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - extend to cover entire screen including safe areas
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 12) {
                                Text(isEditing ? "Edit Your Bet" : "Make Your Bet")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text(partyName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                
                                // NEW: Bet type indicator
                                HStack {
                                    Image(systemName: betTypeIcon)
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16))
                                    Text("\(betType.capitalized) Bet")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(20)
                            }
                            .padding(.top, 20)
                            
                            // Timer/Contest Control Section - show for timer and contest types
                            if betType.lowercased() == "timed" || betType.lowercased() == "contest" {
                                timerContestControlSection
                                    .onAppear {
                                        print("🔍 Timer/Contest section is showing for betType: \(betType)")
                                    }
                            } else {
                                Text("Debug: betType is '\(betType)' - not showing timer")
                                    .foregroundColor(.yellow)
                                    .onAppear {
                                        print("🔍 Timer section NOT showing - betType: '\(betType)'")
                                    }
                            }
                            
                            // Bet Prompt
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Challenge:")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(betPrompt)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 24)
                            
                            if betType.lowercased() == "normal" && !betOptions.isEmpty {
                                selectionRulesSection
                                termsSection
                                optionsSelectionSection
                            } else if betType.lowercased() == "timed" {
                                // For timer bets, show terms but no options selection
                                termsSection
                            }
                            
                            // Error Message
                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.horizontal, 24)
                            }
                            
                            // Submit Button
                            submitButtonSection
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        stopAllTimers()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            // Set navigation bar appearance
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            
            print("🔍 Debug PlaceBetView - betType: '\(betType)'")
            print("🔍 Debug PlaceBetView - betType lowercased: '\(betType.lowercased())'")
            print("🔍 Debug PlaceBetView - timerDuration: \(timerDuration)")
            print("🔍 Debug PlaceBetView - Should show timer: \(betType.lowercased() == "timed")")
            
            // Initialize timer/contest states
            if betType.lowercased() == "timed" {
                timeRemaining = timerDuration
            }
            
            if isEditing {
                Task {
                    await loadExistingBet()
                }
            }
        }
        .onDisappear {
            stopAllTimers()
        }
    }
    
    // MARK: - Timer/Contest Control Section
    
    private var timerContestControlSection: some View {
        VStack(spacing: 16) {
            if betType.lowercased() == "timed" {
                timerControlSection
                    .onAppear {
                        print("🔍 Showing timer control section")
                    }
            } else if betType.lowercased() == "contest" {
                contestControlSection
                    .onAppear {
                        print("🔍 Showing contest control section")
                    }
            } else {
                Text("Debug: Unexpected betType in timerContestControlSection: '\(betType)'")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }
    
    private var timerControlSection: some View {
        VStack(spacing: 16) {
            // Timer Display
            VStack(spacing: 8) {
                Text("Timer")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text(formatTime(timeRemaining))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(getTimerColor())
                
                if timerDuration > 0 {
                    Text("Total Duration: \(formatTime(timerDuration))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Timer Controls
            HStack(spacing: 12) {
                if !hasTimerStarted {
                    Button(action: startTimer) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                            Text("Start")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(10)
                    }
                } else if timerRunning && !isTimerFinished {
                    Button(action: pauseTimer) {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle.fill")
                            Text("Pause")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(10)
                    }
                    
                    if allowEarlyFinish {
                        Button(action: finishEarly) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Finish")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(10)
                        }
                    }
                    
                    Button(action: resetTimer) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Reset")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(10)
                    }
                } else if !timerRunning && hasTimerStarted && !isTimerFinished {
                    Button(action: resumeTimer) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                            Text("Resume")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(10)
                    }
                    
                    Button(action: resetTimer) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Reset")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(10)
                    }
                }
            }
            
            // Timer Status
            if isTimerFinished {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Timer Complete!")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            } else if hasTimerStarted {
                HStack {
                    Image(systemName: timerRunning ? "timer" : "pause.circle")
                        .foregroundColor(.orange)
                    Text(timerRunning ? "Timer Running..." : "Timer Paused")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private var contestControlSection: some View {
        VStack(spacing: 16) {
            // Contest Display
            VStack(spacing: 8) {
                Text("Contest Progress")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                HStack {
                    VStack {
                        Text("Score")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(contestScore)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    Text("/")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    VStack {
                        Text("Target")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(contestTarget)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                
                Text(contestUnit.capitalized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                // Elapsed Time
                if contestStarted {
                    Text("Time: \(formatTime(elapsedTime))")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            
            // Contest Controls
            VStack(spacing: 12) {
                if !contestStarted {
                    Button(action: startContest) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start Contest")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(12)
                    }
                } else if !contestFinished {
                    // Score adjustment buttons
                    HStack(spacing: 16) {
                        Button(action: { adjustScore(-1) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                        }
                        .disabled(contestScore <= 0)
                        
                        Button(action: { adjustScore(1) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button(action: finishContest) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Finish Contest")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(12)
                    }
                }
                
                if contestStarted && !contestFinished {
                    Button(action: resetContest) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Reset Contest")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Contest Status
            if contestFinished {
                let achieved = contestScore >= contestTarget
                HStack {
                    Image(systemName: achieved ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(achieved ? .green : .red)
                    Text(achieved ? "Target Achieved!" : "Target Not Reached")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(achieved ? .green : .red)
                }
                .padding()
                .background((achieved ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(8)
            } else if contestStarted {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text("Contest in Progress...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Normal Bet Sections
    
    private var selectionRulesSection: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            
            Text(maxSelections == 1 ?
                 "Select exactly 1 option" :
                 "Select up to \(maxSelections) options")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
            
            Spacer()
            
            Text("\(selectedOptions.count)/\(maxSelections)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(selectedOptions.count > maxSelections ? .red : .blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal, 24)
    }
    
    private var termsSection: some View {
        Group {
            // Show warning if too many selections
            if selectedOptions.count > maxSelections {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Too many selections! Please choose \(maxSelections == 1 ? "only 1 option" : "up to \(maxSelections) options").")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 24)
            }
            
            // Bet Terms (if available)
            if !betTerms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terms & Conditions:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)
                    
                    Text(betTerms)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var optionsSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your answer(s):")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
            
            ForEach(betOptions, id: \.self) { option in
                Button(action: {
                    toggleOption(option)
                }) {
                    HStack {
                        Image(systemName: selectedOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedOptions.contains(option) ? .blue : .white.opacity(0.6))
                            .font(.system(size: 20))
                        
                        Text(option)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        selectedOptions.contains(option)
                        ? Color.blue.opacity(0.2)
                        : Color.white.opacity(0.1)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedOptions.contains(option)
                                ? Color.blue
                                : Color.white.opacity(0.2),
                                lineWidth: selectedOptions.contains(option) ? 2 : 1
                            )
                    )
                }
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var submitButtonSection: some View {
        Button(action: {
            Task {
                if isEditing {
                    await updateBet()
                } else {
                    await placeBet()
                }
            }
        }) {
            HStack {
                Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                Text(isEditing ? "Update Bet" : getSubmitButtonText())
            }
            .font(.system(size: 20, weight: .bold))
            .padding(.vertical, 14)
            .padding(.horizontal, 32)
            .background(canSubmit ? Color.orange.opacity(0.9) : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(!canSubmit)
        .padding(.top, 20)
    }
    
    // MARK: - Computed Properties
    
    private var betTypeIcon: String {
        switch betType.lowercased() {
        case "timed": return "timer"
        case "contest": return "trophy.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private func getSubmitButtonText() -> String {
        switch betType.lowercased() {
        case "timed":
            if isTimerFinished {
                return "Submit Timer Result"
            } else {
                return "Place Timer Bet"
            }
        case "contest":
            if contestFinished {
                return "Submit Contest Result"
            } else {
                return "Place Contest Bet"
            }
        default:
            return "Place Bet"
        }
    }
    
    // Computed property to check if submission is allowed
    private var canSubmit: Bool {
        switch betType.lowercased() {
        case "normal":
            return !selectedOptions.isEmpty && selectedOptions.count <= maxSelections
        case "timed":
            return true // Timer bets can always be submitted
        case "contest":
            return true // Contest bets can always be submitted
        default:
            return !selectedOptions.isEmpty && selectedOptions.count <= maxSelections
        }
    }
    
    // MARK: - Timer Functions
    
    private func startTimer() {
        hasTimerStarted = true
        timerRunning = true
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                finishTimer()
            }
        }
    }
    
    private func pauseTimer() {
        timerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func resumeTimer() {
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                finishTimer()
            }
        }
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
        hasTimerStarted = false
        isTimerFinished = false
        timeRemaining = timerDuration
        startTime = nil
        endTime = nil
    }
    
    private func finishTimer() {
        timer?.invalidate()
        timer = nil
        timerRunning = false
        isTimerFinished = true
        endTime = Date()
    }
    
    private func finishEarly() {
        finishTimer()
    }
    
    private func getTimerColor() -> Color {
        if isTimerFinished {
            return .green
        } else if timeRemaining <= 10 {
            return .red
        } else if timeRemaining <= 30 {
            return .orange
        } else {
            return .white
        }
    }
    
    // MARK: - Contest Functions
    
    private func startContest() {
        contestStarted = true
        startTime = Date()
        
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    private func adjustScore(_ change: Int) {
        let newScore = contestScore + change
        if newScore >= 0 {
            contestScore = newScore
        }
    }
    
    private func finishContest() {
        contestFinished = true
        endTime = Date()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
    
    private func resetContest() {
        contestScore = 0
        elapsedTime = 0
        contestStarted = false
        contestFinished = false
        startTime = nil
        endTime = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
    
    // MARK: - Helper Functions
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func stopAllTimers() {
        timer?.invalidate()
        timer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
    
    // Function to handle option toggling with max selection logic (for normal bets)
    private func toggleOption(_ option: String) {
        if selectedOptions.contains(option) {
            // Always allow deselection
            selectedOptions.remove(option)
        } else {
            // Check if we can add more selections
            if selectedOptions.count < maxSelections {
                selectedOptions.insert(option)
            } else if maxSelections == 1 {
                // For single selection, replace the current selection
                selectedOptions.removeAll()
                selectedOptions.insert(option)
            }
            // For multiple selections, if at limit, don't add more
        }
    }

    private func loadExistingBet() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await supabaseClient
                .from("User Bets")
                .select("id, bet_selection")
                .eq("user_id", value: userId)
                .eq("party_id", value: Int(partyId))
                .limit(1)
                .execute()
            
            struct ExistingBet: Codable {
                let id: Int64
                let bet_selection: String
            }
            
            let existingBets = try JSONDecoder().decode([ExistingBet].self, from: response.data)
            
            if let existingBet = existingBets.first {
                // Parse the bet_selection back into an array for normal bets
                if betType.lowercased() == "normal" {
                    let optionsArray = existingBet.bet_selection.components(separatedBy: ", ")
                    await MainActor.run {
                        self.existingBetId = existingBet.id
                        self.selectedOptions = Set(optionsArray)
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.existingBetId = existingBet.id
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Could not load existing bet"
                    self.isLoading = false
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Error loading existing bet: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func placeBet() async {
        // Validate based on bet type
        guard canSubmit else {
            await MainActor.run {
                self.errorMessage = getValidationMessage()
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            struct BetInsert: Codable {
                let party_id: Int64
                let user_id: String
                let bet_selection: String
                let is_winner: Bool?
                let start_time: String?  // NEW
                let end_time: String?    // NEW
                let final_score: Int?    // NEW for contest
                let elapsed_time: Int?   // NEW
            }
            
            let selectedOptionText = getBetSelectionText()
            
            // Format timestamps
            let startTimeString = startTime?.ISO8601Format()
            let endTimeString = endTime?.ISO8601Format()
            
            let betData = BetInsert(
                party_id: partyId,
                user_id: userId,
                bet_selection: selectedOptionText,
                is_winner: nil,
                start_time: startTimeString,
                end_time: endTimeString,
                final_score: betType.lowercased() == "contest" ? contestScore : nil,
                elapsed_time: betType.lowercased() == "contest" ? elapsedTime : nil
            )
            
            _ = try await supabaseClient
                .from("User Bets")
                .insert(betData)
                .execute()
            
            await MainActor.run {
                self.isLoading = false
            }
            
            stopAllTimers()
            dismiss()
            
        } catch {
            print("❌ Error placing bet: \(error)")
            
            let errorDescription: String
            if error.localizedDescription.contains("404") {
                errorDescription = "Table 'User Bets' not found. Please check your database setup."
            } else if error.localizedDescription.contains("status code") {
                errorDescription = "Database connection error. Please try again."
            } else {
                errorDescription = error.localizedDescription
            }
            
            await MainActor.run {
                self.errorMessage = "Failed to place bet: \(errorDescription)"
                self.isLoading = false
            }
        }
    }
    
    struct BetUpdateData: Encodable {
        let bet_selection: String
        let start_time: String?
        let end_time: String?
        let final_score: Int?
        let elapsed_time: Int?
    }
    
    private func updateBet() async {
        guard let betId = existingBetId else {
            await MainActor.run {
                self.errorMessage = "Cannot update bet: missing bet ID"
            }
            return
        }

        // Validate based on bet type
        guard canSubmit else {
            await MainActor.run {
                self.errorMessage = getValidationMessage()
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let selectedOptionText = getBetSelectionText()

            // Format timestamps
            let startTimeString = startTime?.ISO8601Format()
            let endTimeString = endTime?.ISO8601Format()

            // Build update payload
            let updateData = BetUpdateData(
                bet_selection: selectedOptionText,
                start_time: startTimeString,
                end_time: endTimeString,
                final_score: betType.lowercased() == "contest" ? contestScore : nil,
                elapsed_time: betType.lowercased() == "contest" ? elapsedTime : nil
            )

            // Send update to Supabase
            _ = try await supabaseClient
                .from("User Bets")
                .update(updateData)
                .eq("id", value: Int(betId))
                .execute()

            await MainActor.run {
                self.isLoading = false
            }

            stopAllTimers()
            dismiss()

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update bet: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func getBetSelectionText() -> String {
        switch betType.lowercased() {
        case "normal":
            return Array(selectedOptions).joined(separator: ", ")
        case "timed":
            if isTimerFinished {
                let actualDuration = timerDuration - timeRemaining
                return "Task completed in \(formatTime(actualDuration))"
            } else if hasTimerStarted {
                return "Timer started - Task in progress"
            } else {
                return "Ready to start timer challenge"
            }
        case "contest":
            if contestFinished {
                return "Score: \(contestScore)/\(contestTarget) \(contestUnit)"
            } else if contestStarted {
                return "Contest started - Score: \(contestScore)"
            } else {
                return "Contest not started"
            }
        default:
            return Array(selectedOptions).joined(separator: ", ")
        }
    }
    
    private func getValidationMessage() -> String {
        switch betType.lowercased() {
        case "normal":
            if selectedOptions.isEmpty {
                return "Please select at least one option."
            } else if selectedOptions.count > maxSelections {
                return maxSelections == 1 ?
                    "Please select exactly 1 option." :
                    "Please select up to \(maxSelections) options."
            }
        case "timed":
            if !hasTimerStarted {
                return "Start the timer to begin the challenge."
            }
            return "" // No validation issues for started timer
        case "contest":
            return "" // No validation needed for contest
        default:
            break
        }
        return ""
    }
    
    // MARK: - Timer-specific validation for submission
    private func canSubmitTimerBet() -> Bool {
        // For timer bets, user must have at least started the timer to submit
        return hasTimerStarted
    }
}

#Preview {
    PlaceBetView(
        partyId: 1,
        userId: "user123",
        partyName: "Test Party",
        betPrompt: "Complete this challenge within the time limit",
        betOptions: ["Option A", "Option B", "Option C"],
        betTerms: "Complete the task within the given timeframe",
        maxSelections: 1,
        betType: "timed",
        timerDuration: 300, // 5 minutes
        allowEarlyFinish: true,
        contestUnit: "points",
        contestTarget: 100,
        allowTies: false,
        isEditing: false
    )
    .environmentObject(SessionManager(supabaseClient: SupabaseClient(
        supabaseURL: URL(string: "https://example.supabase.co")!,
        supabaseKey: "public-anon-key"
    )))
}
