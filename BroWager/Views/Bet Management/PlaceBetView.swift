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
    let betType: String
    let timerDuration: Int
    let allowEarlyFinish: Bool
    let contestUnit: String
    let contestTarget: Int
    let allowTies: Bool
    let isEditing: Bool
    
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOptions: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var existingBetId: Int64? = nil
    
    // Timer/Contest specific states
    @State private var timeRemaining: Int = 0
    @State private var timerRunning = false
    @State private var timer: Timer?
    @State private var hasTimerStarted = false
    @State private var isTimerFinished = false
    @State private var startTime: Date?
    @State private var endTime: Date?
    
    // Contest specific states
    @State private var contestScore: Int = 0
    @State private var contestStarted = false
    @State private var contestFinished = false
    @State private var elapsedTime: Int = 0
    @State private var elapsedTimer: Timer?
    @State private var targetAchievedTime: Int? = nil // NEW: Track when target was achieved
    
    private struct BetCompletionUpdate: Encodable {
        let completed_in_time: Bool
        let score: Int
        let end_time: String?
        let elapsed_time: Int? // NEW: Add elapsed time for contest completion
    }

    private var isTimerBet: Bool {
        let normalizedBetType = betType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedBetType == "timed"
    }

    private var isContestBet: Bool {
        let normalizedBetType = betType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedBetType == "contest"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
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
                            
                            // Timer/Contest Control Section
                            if betType.lowercased() == "timed" || betType.lowercased() == "contest" {
                                timerContestControlSection
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
        }
        .onAppear {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            
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
            } else if betType.lowercased() == "contest" {
                contestControlSection
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
                } else if timerRunning && !isTimerFinished && timeRemaining > 0 {
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
                } else if !timerRunning && hasTimerStarted && !isTimerFinished && timeRemaining > 0 {
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
                else if timeRemaining <= 0 && !isTimerFinished {
                    VStack(spacing: 8) {
                        Text("Time's up! Did you complete the task?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 12) {
                            Button(action: markTaskCompleted) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Yes, Completed")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(8)
                            }
                            
                            Button(action: markTaskNotCompleted) {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("No, Did Not Complete")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            // Timer Status
            if isTimerFinished {
                let completedInTime = endTime != nil && startTime != nil &&
                                     endTime!.timeIntervalSince(startTime!) < Double(timerDuration)
                HStack {
                    Image(systemName: completedInTime ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(completedInTime ? .green : .red)
                    Text(completedInTime ? "Task Completed in Time!" : "Time Expired")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(completedInTime ? .green : .red)
                }
                .padding()
                .background((completedInTime ? Color.green : Color.red).opacity(0.1))
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
                
                // NEW: Show target achieved time
                if let achievedTime = targetAchievedTime {
                    Text("🎯 Target achieved in: \(formatTime(achievedTime))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Contest Controls - SWITCHED ORDER: Score buttons first, then timer
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
                    // LARGER Score adjustment buttons - moved above timer
                    HStack(spacing: 24) {
                        Button(action: { adjustScore(-1) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40)) // INCREASED from 24 to 40
                                .foregroundColor(.red)
                        }
                        .disabled(contestScore <= 0)
                        
                        Button(action: { adjustScore(1) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40)) // INCREASED from 24 to 40
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // Elapsed Time - moved below the score buttons
                    if contestStarted {
                        Text("Time: \(formatTime(elapsedTime))")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: finishContest) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Quit and Accept Loss")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(12)
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
    
    private var canSubmit: Bool {
        switch betType.lowercased() {
        case "normal":
            return !selectedOptions.isEmpty && selectedOptions.count <= maxSelections
        case "timed":
            return true
        case "contest":
            return true
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
        stopAllTimers()
        isTimerFinished = true
        endTime = Date()
    }
    
    private func markTaskCompleted() {
        stopAllTimers()
        isTimerFinished = true
        endTime = Date()
        
        Task {
            await storeBetCompletion(completedInTime: true, score: 1)
        }
    }
    
    private func markTaskNotCompleted() {
        stopAllTimers()
        isTimerFinished = true
        endTime = Date()
        
        Task {
            await storeBetCompletion(completedInTime: false, score: 0)
        }
    }
    
    private func finishEarly() {
        stopAllTimers()
        isTimerFinished = true
        endTime = Date()
        
        // Don't update win/loss status here - only store completion data
        Task {
            await storeBetCompletion(completedInTime: true, score: 1)
        }
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
            
            // Check if target reached for the first time
            if contestScore >= contestTarget && !contestFinished && targetAchievedTime == nil {
                targetAchievedTime = elapsedTime
                autoCompleteContest()
            }
        }
    }
    
    private func autoCompleteContest() {
        contestFinished = true
        endTime = Date()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        
        print("🎉 Contest auto-completed! Target reached in \(targetAchievedTime ?? elapsedTime) seconds")
        
        // Don't update win/loss status here - only store completion data
        Task {
            await storeBetCompletion(completedInTime: true, score: contestScore)
        }
    }
    
    private func finishContest() {
        contestFinished = true
        endTime = Date()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        
        // Don't update win/loss status here - only store completion data
        let achievedTarget = contestScore >= contestTarget
        
        Task {
            await storeBetCompletion(completedInTime: achievedTarget, score: contestScore)
        }
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
    
    private func toggleOption(_ option: String) {
        if selectedOptions.contains(option) {
            selectedOptions.remove(option)
        } else {
            if selectedOptions.count < maxSelections {
                selectedOptions.insert(option)
            } else if maxSelections == 1 {
                selectedOptions.removeAll()
                selectedOptions.insert(option)
            }
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
                if betType.lowercased() == "normal" {
                    let optionsArray = existingBet.bet_selection.components(separatedBy: ", ")
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
                let start_time: String?
                let end_time: String?
                let final_score: Int?
                let elapsed_time: Int?
                let completed_in_time: Bool? // NEW: Add this field
            }
            
            let selectedOptionText = getBetSelectionText()
            let startTimeString = startTime?.ISO8601Format()
            let endTimeString = endTime?.ISO8601Format()
            
            // For contest bets, use the time when target was achieved, not total elapsed time
            let completionTime = betType.lowercased() == "contest" ? targetAchievedTime : elapsedTime
            
            let betData = BetInsert(
                party_id: partyId,
                user_id: userId,
                bet_selection: selectedOptionText,
                is_winner: nil, // Don't set winner status until game ends
                start_time: startTimeString,
                end_time: endTimeString,
                final_score: betType.lowercased() == "contest" ? contestScore : nil,
                elapsed_time: completionTime,
                completed_in_time: getCompletedInTimeStatus()
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
        let completed_in_time: Bool?
    }
    
    private func updateBet() async {
        guard let betId = existingBetId else {
            await MainActor.run {
                self.errorMessage = "Cannot update bet: missing bet ID"
            }
            return
        }

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
            let startTimeString = startTime?.ISO8601Format()
            let endTimeString = endTime?.ISO8601Format()
            let completionTime = betType.lowercased() == "contest" ? targetAchievedTime : elapsedTime

            let updateData = BetUpdateData(
                bet_selection: selectedOptionText,
                start_time: startTimeString,
                end_time: endTimeString,
                final_score: betType.lowercased() == "contest" ? contestScore : nil,
                elapsed_time: completionTime,
                completed_in_time: getCompletedInTimeStatus()
            )

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
                let achievedTimeText = targetAchievedTime != nil ? " (achieved in \(formatTime(targetAchievedTime!)))" : ""
                return "Score: \(contestScore)/\(contestTarget) \(contestUnit)\(achievedTimeText)"
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
            return ""
        case "contest":
            return ""
        default:
            break
        }
        return ""
    }
    
    private func getCompletedInTimeStatus() -> Bool? {
        switch betType.lowercased() {
        case "timed":
            if isTimerFinished {
                return endTime != nil && startTime != nil &&
                       endTime!.timeIntervalSince(startTime!) < Double(timerDuration)
            }
            return nil
        case "contest":
            return contestScore >= contestTarget
        default:
            return nil
        }
    }
    
    // MARK: - Store Bet Completion (without setting winner status)
    private func storeBetCompletion(completedInTime: Bool, score: Int) async {
        do {
            let completionTime = betType.lowercased() == "contest" ? targetAchievedTime : elapsedTime
            
            let updateData = BetCompletionUpdate(
                completed_in_time: completedInTime,
                score: score,
                end_time: endTime?.ISO8601Format(),
                elapsed_time: completionTime
            )
            
            _ = try await supabaseClient
                .from("User Bets")
                .update(updateData)
                .eq("party_id", value: Int(partyId))
                .eq("user_id", value: userId)
                .execute()
            
            print("✅ Bet completion stored - Completed: \(completedInTime), Score: \(score), Time: \(completionTime ?? 0)")
        } catch {
            print("❌ Failed to store bet completion: \(error)")
        }
    }
}
