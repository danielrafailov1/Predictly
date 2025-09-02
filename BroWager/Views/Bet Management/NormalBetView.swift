// Updated Bet Creation Flow with Optional Date
import SwiftUI

struct NormalBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let userId: UUID?
    let selectedCategory: BetCategoryView.BetCategory?
    let betType: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var isDateEnabled = false
    @State private var aiSuggestions: [String] = []
    @State private var betPrompt: String = ""
    @State private var selectedDate = Date()
    @State private var isNextActive = false
    @State private var optionCount = 2
    @State private var max_selections = 1
    @State private var showDateInfo = false
    @State private var isOptimizingQuestion = false
    @State private var timerDays = 0
    @State private var timerHours = 0
    @State private var timerMinutes = 0
    @State private var timerSeconds = 0

    // NEW: Optimization states
    @State private var optimizedBetPrompt: String = ""
    @State private var showOptimization = false
    @State private var isProcessingOptimization = false

    // UPDATED: Shared cooldown states - using AppStorage for persistence
    @AppStorage("sharedRefreshCount") private var sharedRefreshCount = 0
    @AppStorage("lastSharedRefreshTimestamp") private var lastSharedRefreshTimestamp: Double = 0
    @State private var isSharedRefreshDisabled = false
    @State private var cooldownTimer: Timer?
    @State private var timeRemaining: Int = 0

    // Date picker states
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedDay = Calendar.current.component(.day, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isProcessingDate = false
    @State private var detectedDateText: String = ""

    // Word limit constants for bet prompt
    private let maxWordsInBetPrompt = 100 // Adjust this value as needed

    private let months = Array(1...12)
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let maxSharedRefreshesPerMinute = 3

    private var years: [Int] {
        Array(currentYear...(currentYear + 5))
    }

    private var days: [Int] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = 1

        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return Array(1...31)
        }

        return Array(1...range.count)
    }

    // Word count helper for bet prompt
    private func wordCount(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

    private var currentBetPromptWordCount: Int {
        wordCount(in: betPrompt)
    }

    private var isBetPromptOverWordLimit: Bool {
        currentBetPromptWordCount > maxWordsInBetPrompt
    }

    // Validation computed property
    private var canProceed: Bool {
        !betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBetPromptOverWordLimit
    }

    // UPDATED: Computed property for remaining shared refreshes
    private var remainingSharedRefreshes: Int {
        return maxSharedRefreshesPerMinute - sharedRefreshCount
    }

    @ViewBuilder
    private var betTypeSpecificView: some View {
        if betType == "normal" {
            normalBetOptions
        } else if betType == "timed" {
            timedBetOptions
        }
    }

    private var navigationSection: some View {
        Group {
            NavigationLink(
                destination: BetOptionsView(
                    navPath: $navPath,
                    betPrompt: betPrompt,
                    selectedDate:  selectedDate,
                    email: email,
                    userId: userId,
                    optionCount: optionCount,
                    max_selections: max_selections,
                    selectedCategory: selectedCategory,
                    betType: betType,
                    timerDays: timerDays,
                    timerHours: timerHours,
                    timerMinutes: timerMinutes,
                    timerSeconds: timerSeconds
                ),
                isActive: $isNextActive
            ) {
                EmptyView()
            }

            Button(action: {
                if canProceed {
                    isNextActive = true
                }
            }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canProceed ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            .disabled(!canProceed)

            if !canProceed {
                VStack(spacing: 4) {
                    if betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Please enter a challenge question to continue")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    if isBetPromptOverWordLimit {
                        Text("Challenge question exceeds \(maxWordsInBetPrompt) word limit (\(currentBetPromptWordCount) words)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var normalBetOptions: some View {
        Group {
            // Number of Options Section
            VStack(spacing: 12) {
                HStack {
                    Text("Number of options")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))

                    Spacer()

                    // Counter/Ticker on the right
                    HStack(spacing: 16) {
                        Button(action: {
                            if optionCount > 2 {
                                optionCount -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(optionCount > 2 ? .blue : .gray)
                                .font(.title2)
                        }
                        .disabled(optionCount <= 2)

                        Text("\(optionCount)")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(minWidth: 30)

                        Button(action: {
                            if optionCount < 10 {
                                optionCount += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(optionCount < 10 ? .blue : .gray)
                                .font(.title2)
                        }
                        .disabled(optionCount >= 10)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)

            // Maximum Selections Section
            VStack(spacing: 12) {
                HStack {
                    Text("Max selections per user")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))

                    Spacer()

                    // Counter/Ticker on the right
                    HStack(spacing: 16) {
                        Button(action: {
                            if max_selections > 1 {
                                max_selections -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(max_selections > 1 ? .blue : .gray)
                                .font(.title2)
                        }
                        .disabled(max_selections <= 1)

                        Text("\(max_selections)")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(minWidth: 30)

                        Button(action: {
                            if max_selections < (optionCount - 1) {
                                max_selections += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(max_selections < (optionCount - 1) ? .blue : .gray)
                                .font(.title2)
                        }
                        .disabled(max_selections >= (optionCount - 1))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private var timedBetOptions: some View {
        VStack(alignment: .leading) {
            Text("Set Timer")
                .font(.title2)
                .foregroundColor(.white)
                .padding(.leading)

            HStack {
                TimerSetView(title: "days", range: 0...7, binding: $timerDays)
                TimerSetView(title: "hours", range: 0...23, binding: $timerHours)
                TimerSetView(title: "min", range: 0...59, binding: $timerMinutes)
                TimerSetView(title: "sec", range: 0...59, binding: $timerSeconds)
            }
            .frame(height: 100)
        }
    }

    // Function to enforce word limit for bet prompt
    private func enforceBetPromptWordLimit(_ newValue: String) {
        let words = newValue.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // If over the limit, truncate to the word limit
        if words.count > maxWordsInBetPrompt {
            let truncatedWords = Array(words.prefix(maxWordsInBetPrompt))
            let truncatedText = truncatedWords.joined(separator: " ")

            // Use a dispatch to avoid binding update conflicts
            DispatchQueue.main.async {
                self.betPrompt = truncatedText
            }

            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }

    // NEW: Optimization section view
    @ViewBuilder
    private var optimizationSection: some View {
        if showOptimization {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Optimized Question")
                        .foregroundColor(.green)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Spacer()

                    // Close optimization button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showOptimization = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }

                // Display optimized version
                Text(optimizedBetPrompt)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.system(size: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green.opacity(0.5), lineWidth: 1)
                    )

                // Action buttons
                HStack(spacing: 12) {
                    // Accept optimization button
                    Button(action: {
                        betPrompt = optimizedBetPrompt
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showOptimization = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Accept")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    }

                    // UPDATED: Regenerate button with shared cooldown
                    Button(action: {
                        Task {
                            await handleSharedRefreshAction {
                                await generateOptimizedBetQuestion()
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isProcessingOptimization {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(isSharedRefreshDisabled ? .gray : .orange)
                            }
                            Text("Regenerate")
                                .foregroundColor(isSharedRefreshDisabled ? .gray : .orange)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background((isSharedRefreshDisabled ? Color.gray : Color.orange).opacity(0.2))
                        .cornerRadius(8)
                    }
                    .disabled(isProcessingOptimization || isSharedRefreshDisabled)

                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            .transition(.opacity.combined(with: .slide))
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Category Header
                    if let category = selectedCategory {
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.trailing, 16)
                                .padding(.vertical, 8)
                                .cornerRadius(20)
                                
                            }
                            .padding(.trailing)
                            
                            Spacer()
                            
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                                .font(.title2)
                            
                            Spacer()
                            
                            Text(category.rawValue)
                                .foregroundColor(.white)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text(category.description)
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }

                    // UPDATED: AI Suggestions Header with shared cooldown
                    VStack(spacing: 12) {
                        HStack {
                            Text("AI Suggestions: Click to fill")
                                .foregroundColor(.white)
                                .font(.title2)

                            Spacer()

                            Button(action: {
                                Task {
                                    await handleSharedRefreshAction {
                                        await refreshAISuggestions()
                                    }
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(isSharedRefreshDisabled ? .gray : .white)
                                    .font(.title2)
                                    .padding(8)
                                    .background((isSharedRefreshDisabled ? Color.gray : Color.blue).opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .disabled(isSharedRefreshDisabled)
                        }
                        .padding(.horizontal)

                        // UPDATED: Cooldown message with shared cooldown info
                        if isSharedRefreshDisabled && timeRemaining > 0 {
                            HStack {
                                Spacer()
                                Text("Cooldown: \(timeRemaining)s remaining")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .padding(.horizontal)
                                Spacer()
                            }
                        } else if sharedRefreshCount > 0 && !isSharedRefreshDisabled {
                            HStack {
                                Spacer()
                                Text("\(remainingSharedRefreshes) refreshes remaining this minute")
                                    .foregroundColor(.white.opacity(0.6))
                                    .font(.caption)
                                    .padding(.horizontal)
                                Spacer()
                            }
                        }
                    }

                    // Scrollable Suggestion Buttons
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(aiSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    // Apply word limit when selecting AI suggestion
                                    let suggestionWords = suggestion.components(separatedBy: .whitespacesAndNewlines)
                                        .filter { !$0.isEmpty }

                                    if suggestionWords.count > maxWordsInBetPrompt {
                                        let truncatedWords = Array(suggestionWords.prefix(maxWordsInBetPrompt))
                                        betPrompt = truncatedWords.joined(separator: " ")
                                    } else {
                                        betPrompt = suggestion
                                    }

                                    // Hide optimization when new suggestion is selected
                                    if showOptimization {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showOptimization = false
                                        }
                                    }
                                }) {
                                    Text(suggestion)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.15))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 150)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Write your Challenge")
                                .foregroundColor(.white)
                                .font(.title2)

                            Spacer()

                            // UPDATED: Optimize button with shared cooldown
                            Button(action: {
                                Task {
                                    await handleSharedRefreshAction {
                                        await generateOptimizedBetQuestion()
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    if isProcessingOptimization {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                            .foregroundColor(isSharedRefreshDisabled ? .gray : .yellow)
                                            .font(.system(size: 16))
                                    }
                                    Text("Optimize")
                                        .foregroundColor(isSharedRefreshDisabled ? .gray : .yellow)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((isSharedRefreshDisabled ? Color.gray : Color.yellow).opacity(0.2))
                                .cornerRadius(8)
                            }
                            .disabled(betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessingOptimization || isSharedRefreshDisabled)
                        }
                        .padding(.vertical)

                        // Word count indicator for bet prompt
                        HStack {
                            Text("Word count: \(currentBetPromptWordCount) / \(maxWordsInBetPrompt)")
                                .font(.caption)
                                .foregroundColor(isBetPromptOverWordLimit ? .red : (currentBetPromptWordCount > maxWordsInBetPrompt * 3/4 ? .orange : .gray))

                            Spacer()

                            if isBetPromptOverWordLimit {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text("Exceeds limit")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.horizontal)

                        TextEditor(text: $betPrompt)
                            .scrollContentBackground(.hidden)
                            .frame(height: 130)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isBetPromptOverWordLimit ? Color.red : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: betPrompt) { newValue in
                                // Enforce word limit
                                enforceBetPromptWordLimit(newValue)

                                // Hide optimization when user starts typing
                                if showOptimization && newValue != optimizedBetPrompt {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showOptimization = false
                                    }
                                }

                                // Detect and process date
                                Task {
                                    await detectAndProcessDate(from: newValue)
                                }
                            }

                        // Word limit warning for bet prompt
                        if isBetPromptOverWordLimit {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)

                                Text("Challenge question exceeds \(maxWordsInBetPrompt) word limit. Text has been automatically truncated.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal)
                        } else if currentBetPromptWordCount > maxWordsInBetPrompt * 3/4 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption)

                                Text("Approaching word limit. Consider keeping the bet question concise.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)

                    // NEW: Show optimization section
                    optimizationSection

                    // Auto-detected Date Display
                    // Auto-detected Date Display
                    // Date Toggle Section with Auto-Detection
                    // Date Toggle Section with Auto-Detection and Manual Override
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Use specific date for challenge")
                                .foregroundColor(.white)
                                .font(.system(size: 18))

                            if isProcessingDate {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.7)
                            }

                            Button(action: {
                                showDateInfo = true
                            }) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }

                            Spacer()

                            Toggle("", isOn: $isDateEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .frame(width: 40)
                                .padding(.trailing, 16)
                        }
                        .padding(.horizontal)

                        // Date Picker Section (shown when toggle is enabled)
                        if isDateEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select or modify the challenge date")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.headline)
                                    .padding(.horizontal)

                                HStack(spacing: 0) {
                                    DatePickerView(title: "Month",
                                                 range: 1...12,
                                                 binding: $selectedMonth,
                                                 formatter: { monthNumber in
                                                     Calendar.current.monthSymbols[monthNumber - 1]
                                                 })

                                    DatePickerView(title: "Day",
                                                 range: 1...days.count,
                                                 binding: $selectedDay)

                                    DatePickerView(title: "Year",
                                                 range: currentYear...(currentYear + 5),
                                                 binding: $selectedYear)
                                }
                                .frame(height: 100)
                                .padding(.horizontal)
                                .onChange(of: selectedMonth) { _ in updateSelectedDate() }
                                .onChange(of: selectedDay) { _ in updateSelectedDate() }
                                .onChange(of: selectedYear) { _ in updateSelectedDate() }

                                // Display selected date
                                HStack {
                                    Spacer()
                                    Text("Selected: \(formattedSelectedDate())")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                            .transition(.opacity.combined(with: .slide))
                        }
                    }

                    betTypeSpecificView

                    navigationSection

                    Spacer()
                }
                .onAppear {
                    loadAISuggestions()
                    checkSharedCooldownStatus()
                    
                    Task {
                        await detectAndProcessDate(from: betPrompt)
                    }
                }
                .onDisappear {
                    cooldownTimer?.invalidate()
                }
            }
        }
        .navigationBarHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .statusBarHidden(false) // Keep status bar visible but dark themed
        .alert("Date Selection Info", isPresented: $showDateInfo) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("The app automatically detects dates from your challenge question when you type phrases like 'tonight', 'tomorrow', 'Christmas', 'January 5th', or '12/25/2025'. Toggle this on to use the detected date, and you can manually adjust it using the date picker below. Leave it off for a general challenge with no specific date.")
        }

    }

    // MARK: - Helper Functions

    // Complete the dateFromComponents function
    private func dateFromComponents() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = selectedDay

        if let date = calendar.date(from: components) {
            return date
        } else {
            // Handle invalid date (e.g., February 30th)
            components.day = 1
            guard let firstOfMonth = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
                return Date()
            }

            // Set to the last valid day of the month
            components.day = min(selectedDay, range.count)
            return calendar.date(from: components) ?? Date()
        }
    }

    // Update selected date when components change
    private func updateSelectedDate() {
        selectedDate = dateFromComponents()
    }

    // Format the selected date for display
    private func formattedSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }

    // NEW: Generate optimized bet question function
    @MainActor
    private func generateOptimizedBetQuestion() async {
        guard !betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isProcessingOptimization = true

        do {
            let categoryContext = selectedCategory?.aiPromptContext ?? "general activities"
            let betTypeContext = getBetTypeContext()

            // Step 1: Create a more specific search query
            let searchQueryPrompt = """
            Generate a specific Google search query to find key details about: "\(betPrompt)"

            Focus on finding:
            - Exact dates and times
            - Names of people, teams, or entities involved
            - Specific locations or venues
            - Final scores, results, or outcomes
            - Any other verifiable facts

            Return only the search query, no explanation.
            """

            let searchQuery = try await AIServices.shared.sendPrompt(
                searchQueryPrompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.1,
                maxTokens: 50
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            // Step 2: Get search results
            let searchResults = try await AIServices.shared.requestWithSearch(prompt: searchQuery)

            // Step 3: Extract key facts from search results
            let factExtractionPrompt = """
            Extract the key verifiable facts from this information: "\(searchResults)"

            Related to the question: "\(betPrompt)"

            Focus on:
            - Specific dates (include day, month, year)
            - Names of all parties/teams/people involved
            - Final scores or results
            - Locations or venues
            - Any other concrete details that make the question more specific

            Return only the key facts in a concise format, no extra text.
            """

            let keyFacts = try await AIServices.shared.sendPrompt(
                factExtractionPrompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.1,
                maxTokens: 150
            )

            // Step 4: Create optimized question with specific details
            let optimizationPrompt = """
            Transform this betting question using the provided facts:

            Original question: "\(betPrompt)"
            Key facts: "\(keyFacts)"
            Category: \(categoryContext)
            Bet type: \(betTypeContext)
            Word limit: \(maxWordsInBetPrompt) words

            Create an improved question that:
            1. Includes specific names of all parties involved (teams, people, etc.)
            2. Includes the exact date when relevant
            3. Is phrased as a clear choice between specific options when possible
            4. Remains under \(maxWordsInBetPrompt) words
            5. Ends with a question mark
            6. Is easily verifiable

            Examples of good transformations:
            - "Who won the 2019 NBA finals" → "Who won the NBA Finals on June 13, 2019: the Toronto Raptors or the Golden State Warriors?"
            - "Will it rain tomorrow" → "Will it rain in [City] on [Date]?"

            Return only the improved question, nothing else.
            """

            let optimizedQuestion = try await AIServices.shared.sendPrompt(
                optimizationPrompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.2,
                maxTokens: 150
            )

            // Clean up and apply word limit
            var cleanedQuestion = optimizedQuestion.trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove any quotes if the AI wrapped the response
            if cleanedQuestion.hasPrefix("\"") && cleanedQuestion.hasSuffix("\"") {
                cleanedQuestion = String(cleanedQuestion.dropFirst().dropLast())
            }

            // Apply word limit
            let words = cleanedQuestion.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            if words.count > maxWordsInBetPrompt {
                let limitedWords = words.prefix(maxWordsInBetPrompt)
                cleanedQuestion = limitedWords.joined(separator: " ")
            }

            // Ensure it ends with a question mark
            if !cleanedQuestion.hasSuffix("?") {
                cleanedQuestion += "?"
            }

            optimizedBetPrompt = cleanedQuestion

            // Show the optimization section
            withAnimation(.easeInOut(duration: 0.3)) {
                showOptimization = true
            }

        } catch {
            print("Failed to optimize bet question: \(error)")

            // Fallback to basic optimization
            optimizedBetPrompt = createBasicOptimization(betPrompt)

            withAnimation(.easeInOut(duration: 0.3)) {
                showOptimization = true
            }
        }

        isProcessingOptimization = false
    }

    private func getBetTypeContext() -> String {
        switch betType {
        case "normal":
            return "a prediction or outcome-based bet where participants guess what will happen"
        case "timed":
            return "a time-based challenge where someone must complete a task within a time limit"
        case "contest":
            return "a competition where multiple people compete to see who performs best"
        default:
            return "a general betting situation"
        }
    }

    // Fallback optimization function
    private func createBasicOptimization(_ question: String) -> String {
        var optimized = question.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter
        if let firstChar = optimized.first {
            optimized = String(firstChar).uppercased() + String(optimized.dropFirst())
        }

        // Add question mark if missing
        if !optimized.hasSuffix("?") {
            optimized += "?"
        }

        // Apply word limit
        let words = optimized.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if words.count > maxWordsInBetPrompt {
            let truncatedWords = Array(words.prefix(maxWordsInBetPrompt))
            optimized = truncatedWords.joined(separator: " ")
            if !optimized.hasSuffix("?") {
                optimized += "?"
            }
        }

        return optimized
    }

    // UPDATED: New shared cooldown handling function
    private func handleSharedRefreshAction(_ action: @escaping () async -> Void) async {
        let currentTime = Date().timeIntervalSince1970

        // Check if it's been more than a minute since last reset
        if currentTime - lastSharedRefreshTimestamp > 60 {
            sharedRefreshCount = 0
            lastSharedRefreshTimestamp = currentTime
        }

        // Check if user has exceeded refresh limit
        if sharedRefreshCount >= maxSharedRefreshesPerMinute {
            isSharedRefreshDisabled = true
            timeRemaining = 60 - Int(currentTime - lastSharedRefreshTimestamp)
            startSharedCooldownTimer()
            return
        }

        // Perform the action
        sharedRefreshCount += 1
        lastSharedRefreshTimestamp = currentTime

        await action()

        // Check if cooldown should start
        if sharedRefreshCount >= maxSharedRefreshesPerMinute {
            isSharedRefreshDisabled = true
            timeRemaining = 60
            startSharedCooldownTimer()
        }
    }

    private func loadAISuggestions() {
        // Show loading state
        aiSuggestions = ["Loading suggestions..."]

        Task {
            do {
                let suggestions = try await AIServices.shared.generateCategoryBetSuggestions(
                    category: selectedCategory,
                    count: 5,
                    betType: betType,
                    wordLimit: maxWordsInBetPrompt
                )

                await MainActor.run {
                    self.aiSuggestions = suggestions
                }

            } catch {
                print("Failed to load AI suggestions: \(error)")

                // Fallback suggestions based on bet type and category
                await MainActor.run {
                    self.aiSuggestions = getFallbackSuggestions()
                }
            }
        }
    }

    private func getFallbackSuggestions() -> [String] {
        switch betType {
        case "normal":
            return getNormalFallbackSuggestions()
        case "timed":
            return getTimedFallbackSuggestions()
        case "contest":
            return getContestFallbackSuggestions()
        default:
            return ["What will happen next?", "Who will win?", "What will be the outcome?"]
        }
    }

    private func getNormalFallbackSuggestions() -> [String] {
        guard let category = selectedCategory else {
            return ["What will happen next?", "Who will win?", "What will be the outcome?"]
        }

        switch category {
        case .sports:
            return ["Who will win the game?", "What will the final score be?", "Which team will score first?"]
        case .food:
            return ["Which dish will taste better?", "Who will finish eating first?", "What will be the most popular menu item?"]
        case .lifeEvents:
            return ["Who will get promoted first?", "Which friend will move next?", "What major life change will happen?"]
        case .politics:
            return ["Who will win the election?", "What policy will pass first?", "Which candidate will lead in polls?"]
        case .entertainment:
            return ["Which movie will be more popular?", "Who will win the award?", "What show will get renewed?"]
        case .other:
            return ["What will happen tomorrow?", "Which option is most likely?", "Who will be right?"]
        }
    }

    private func getTimedFallbackSuggestions() -> [String] {
        guard let category = selectedCategory else {
            return ["Can you complete this challenge before time runs out?", "How fast can you finish this task?", "Can you beat the clock?"]
        }

        switch category {
        case .sports:
            return ["Can you hit 10 free throws before time runs out?", "How many push-ups can you do quickly?", "Can you run a mile as fast as possible?"]
        case .food:
            return ["Can you eat a burger before time runs out?", "How fast can you chop vegetables?", "Can you bake cookies quickly?"]
        case .lifeEvents:
            return ["Can you clean your room before time runs out?", "How fast can you organize your desk?", "Can you reply to all emails quickly?"]
        case .politics:
            return ["Can you name 20 presidents before time runs out?", "How fast can you explain a policy?", "Can you register to vote quickly?"]
        case .entertainment:
            return ["Can you watch a movie before time runs out?", "How fast can you learn song lyrics?", "Can you finish a book quickly?"]
        case .other:
            return ["Can you solve this puzzle before time runs out?", "How fast can you complete this task?", "Can you finish before the timer?"]
        }
    }

    private func getContestFallbackSuggestions() -> [String] {
        guard let category = selectedCategory else {
            return ["Who can do this the fastest?", "Who will perform the best?", "Who can complete this first?"]
        }

        switch category {
        case .sports:
            return ["Who can do the most push-ups?", "Who can run faster?", "Who has better aim?"]
        case .food:
            return ["Who can eat the most hot dogs?", "Who can cook faster?", "Who makes the best dish?"]
        case .lifeEvents:
            return ["Who can save the most money?", "Who will get a job first?", "Who can learn a skill faster?"]
        case .politics:
            return ["Who knows more about politics?", "Who can debate better?", "Who can name more senators?"]
        case .entertainment:
            return ["Who can sing better?", "Who knows more movie trivia?", "Who can dance longer?"]
        case .other:
            return ["Who can solve this faster?", "Who will be more accurate?", "Who performs better?"]
        }
    }

    private func refreshAISuggestions() async {
        await MainActor.run {
            self.aiSuggestions = ["Loading new suggestions..."]
        }

        do {
            let suggestions = try await AIServices.shared.generateCategoryBetSuggestions(
                category: selectedCategory,
                count: 5,
                betType: betType,
                wordLimit: maxWordsInBetPrompt
            )

            await MainActor.run {
                self.aiSuggestions = suggestions
            }

        } catch {
            print("Failed to refresh AI suggestions: \(error)")

            // Use fallback suggestions
            await MainActor.run {
                self.aiSuggestions = getFallbackSuggestions()
                // Shuffle to make them appear different
                self.aiSuggestions.shuffle()
            }
        }
    }

    // UPDATED: Shared cooldown timer
    private func startSharedCooldownTimer() {
        cooldownTimer?.invalidate()

        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.timeRemaining -= 1

                if self.timeRemaining <= 0 {
                    self.isSharedRefreshDisabled = false
                    self.cooldownTimer?.invalidate()
                    self.cooldownTimer = nil
                }
            }
        }
    }

    // UPDATED: Check shared cooldown status on appear
    private func checkSharedCooldownStatus() {
        let currentTime = Date().timeIntervalSince1970

        // Reset refresh count if more than a minute has passed
        if currentTime - lastSharedRefreshTimestamp > 60 {
            sharedRefreshCount = 0
            isSharedRefreshDisabled = false
            return
        }

        // Check if still in cooldown
        if sharedRefreshCount >= maxSharedRefreshesPerMinute {
            timeRemaining = 60 - Int(currentTime - lastSharedRefreshTimestamp)
            if timeRemaining > 0 {
                isSharedRefreshDisabled = true
                startSharedCooldownTimer()
            } else {
                sharedRefreshCount = 0
                isSharedRefreshDisabled = false
            }
        }
    }

    // Detect and process date from text
    private func detectAndProcessDate(from text: String) async {
        isProcessingDate = true
        
        let detectedDate = parseDate(from: text) ?? Date() // Always fallback to today
        
        await MainActor.run {
            selectedDate = detectedDate
            
            // Update picker components so manual selection shows the detected date
            let calendar = Calendar.current
            selectedYear = calendar.component(.year, from: selectedDate)
            selectedMonth = calendar.component(.month, from: selectedDate)
            selectedDay = calendar.component(.day, from: selectedDate)
        }
        
        isProcessingDate = false
    }

    private func parseDate(from text: String) -> Date? {
        let lowercaseText = text.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        // Holiday keywords mapping to 2025 dates
        let holidays: [String: (month: Int, day: Int)] = [
            "halloween": (10, 31),
            "christmas": (12, 25),
            "new years": (1, 1),
            "new year": (1, 1),
            "easter": (4, 20), // Easter 2025
            "valentines": (2, 14),
            "valentine": (2, 14),
            "thanksgiving": (11, 27), // Thanksgiving 2025
            "independence day": (7, 4),
            "july 4th": (7, 4),
            "memorial day": (5, 26), // Memorial Day 2025
            "labor day": (9, 1) // Labor Day 2025
        ]
        
        // Check for holiday keywords first
        for (keyword, date) in holidays {
            if lowercaseText.contains(keyword) {
                var components = DateComponents()
                components.year = 2025 // Default to 2025 for holidays
                components.month = date.month
                components.day = date.day
                return calendar.date(from: components)
            }
        }
        
        // Relative date keywords
        if lowercaseText.contains("tonight") || lowercaseText.contains("today") {
            return now
        } else if lowercaseText.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercaseText.contains("sunday") {
            return getNextWeekday(1, from: now)
        } else if lowercaseText.contains("monday") {
            return getNextWeekday(2, from: now)
        } else if lowercaseText.contains("tuesday") {
            return getNextWeekday(3, from: now)
        } else if lowercaseText.contains("wednesday") {
            return getNextWeekday(4, from: now)
        } else if lowercaseText.contains("thursday") {
            return getNextWeekday(5, from: now)
        } else if lowercaseText.contains("friday") {
            return getNextWeekday(6, from: now)
        } else if lowercaseText.contains("saturday") {
            return getNextWeekday(7, from: now)
        }
        
        // Try various date formats
        let dateFormats = [
            "MMMM d, yyyy",      // January 5, 2025
            "MMMM dd, yyyy",     // January 05, 2025
            "MMM d, yyyy",       // Jan 5, 2025
            "MMM dd, yyyy",      // Jan 05, 2025
            "MM/dd/yyyy",        // 01/05/2025
            "MM/dd/yy",          // 01/05/25
            "M/d/yyyy",          // 1/5/2025
            "M/d/yy",            // 1/5/25
            "dd/MM/yyyy",        // 05/01/2025
            "d/MM/yyyy",         // 5/01/2025
            "yyyy-MM-dd",        // 2025-01-05
            "MMMM d",            // January 5 (current year)
            "MMM d",             // Jan 5 (current year)
            "MM/dd",             // 01/05 (current year)
            "M/d"                // 1/5 (current year)
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        
        for format in dateFormats {
            dateFormatter.dateFormat = format
            
            // Try to find date patterns in the text
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                if let date = dateFormatter.date(from: word) {
                    // For formats without year, assume current year or next year if date has passed
                    if !format.contains("yyyy") && !format.contains("yy") {
                        var components = calendar.dateComponents([.year, .month, .day], from: date)
                        components.year = calendar.component(.year, from: now)
                        
                        if let dateWithYear = calendar.date(from: components) {
                            // If the date has already passed this year, assume next year
                            if dateWithYear < now {
                                components.year! += 1
                                return calendar.date(from: components)
                            }
                            return dateWithYear
                        }
                    }
                    return date
                }
            }
            
            // Also try multi-word combinations
            let text = text.replacingOccurrences(of: "st|nd|rd|th", with: "", options: .regularExpression)
            if let date = dateFormatter.date(from: text) {
                if !format.contains("yyyy") && !format.contains("yy") {
                    var components = calendar.dateComponents([.year, .month, .day], from: date)
                    components.year = calendar.component(.year, from: now)
                    
                    if let dateWithYear = calendar.date(from: components) {
                        if dateWithYear < now {
                            components.year! += 1
                            return calendar.date(from: components)
                        }
                        return dateWithYear
                    }
                }
                return date
            }
        }
        
        return nil // Return nil to use fallback (today's date)
    }

    private func getNextWeekday(_ weekday: Int, from date: Date) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let daysUntilTarget = (weekday - currentWeekday + 7) % 7
        let targetDate = calendar.date(byAdding: .day, value: daysUntilTarget == 0 ? 7 : daysUntilTarget, to: date) ?? date
        return targetDate
    }
}

// Placeholder AIServices class if not defined elsewhere
extension AIServices {
    
    func generateSportsOptimizedBetQuestion(
        originalQuestion: String,
        category: BetCategoryView.BetCategory?,
        wordLimit: Int
    ) async throws -> String {
        print("🔄 Starting optimization for: '\(originalQuestion)'")
        print("🏷️ Category: \(category?.rawValue ?? "nil")")
        
        let lowercaseQuestion = originalQuestion.lowercased()
        
        // Extract team/player and time information from the question
        let (extractedTeam, timeInfo) = extractTeamAndTimeInfo(from: originalQuestion)
        print("🔍 Extracted team: '\(extractedTeam)', time: '\(timeInfo)'")
        
        // Convert relative time to specific date
        let targetDate = convertRelativeTimeToDate(timeInfo)
        let dateString = formatDateForSearch(targetDate)
        print("📅 Target date: \(dateString)")
        
        // For sports questions, always try to optimize even if no specific team is found
        if category == .sports {
            // If no specific team found, create a generic search based on the question
            let teamOrQuery = extractedTeam.isEmpty ? extractSportsKeywords(from: originalQuestion) : extractedTeam
            print("🏀 Using team/query: '\(teamOrQuery)'")
            
            if !teamOrQuery.isEmpty {
                // Create search query to find opponent information
                let searchQuery = buildSearchQuery(team: teamOrQuery, date: dateString, question: lowercaseQuestion)
                print("🔎 Search query: '\(searchQuery)'")
                
                do {
                    // Use the Google Search API to find opponent information
                    let searchResults = try await performSportsOptimizedGoogleSearch(
                        query: searchQuery,
                        numResults: 8,
                        dateRange: "d7" // Last week for more results
                    )
                    print("📋 Got search results (length: \(searchResults.count) chars)")
                    
                    // Extract opponent information from search results
                    let opponentInfo = extractOpponentFromSearchResults(
                        searchResults: searchResults,
                        originalTeam: teamOrQuery,
                        targetDate: targetDate
                    )
                    print("⚔️ Found opponent: '\(opponentInfo)'")
                    
                    // Create optimized question with opponent information
                    let optimizedQuestion = createOptimizedQuestion(
                        originalQuestion: originalQuestion,
                        teamInfo: teamOrQuery,
                        opponentInfo: opponentInfo,
                        date: targetDate,
                        wordLimit: wordLimit
                    )
                    print("✅ Final optimized question: '\(optimizedQuestion)'")
                    return optimizedQuestion
                    
                } catch {
                    print("❌ Google Search failed: \(error)")
                    // Still try to create a better question with what we have
                    return createEnhancedOptimization(originalQuestion, team: teamOrQuery, date: targetDate, wordLimit: wordLimit)
                }
            }
        }
        
        print("🔄 Using basic optimization")
        return createBasicOptimization(originalQuestion, wordLimit: wordLimit)
    }
    
    private func extractTeamAndTimeInfo(from question: String) -> (team: String, timeInfo: String) {
        let lowercaseQuestion = question.lowercased()
        print("🔍 Analyzing question: '\(lowercaseQuestion)'")
        
        // Expanded team mappings including more variations
        let teamMappings: [String: String] = [
            "blue jays": "Toronto Blue Jays",
            "jays": "Toronto Blue Jays",
            "yankees": "New York Yankees",
            "red sox": "Boston Red Sox",
            "sox": "Boston Red Sox",
            "lakers": "Los Angeles Lakers",
            "warriors": "Golden State Warriors",
            "celtics": "Boston Celtics",
            "cowboys": "Dallas Cowboys",
            "patriots": "New England Patriots",
            "chiefs": "Kansas City Chiefs",
            "dodgers": "Los Angeles Dodgers",
            "giants": "San Francisco Giants",
            "knicks": "New York Knicks",
            "heat": "Miami Heat",
            "bulls": "Chicago Bulls",
            "packers": "Green Bay Packers",
            "steelers": "Pittsburgh Steelers"
        ]
        
        var extractedTeam = ""
        var timeInfo = ""
        
        // Extract team names - check mappings first
        for (shortName, fullName) in teamMappings {
            if lowercaseQuestion.contains(shortName) {
                extractedTeam = fullName
                print("✅ Found team mapping: '\(shortName)' -> '\(fullName)'")
                break
            }
        }
        
        // If no mapping found, look for potential team names or player names
        if extractedTeam.isEmpty {
            let words = question.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                .filter { !$0.isEmpty && $0.count > 2 }
            
            for word in words {
                if word.first?.isUppercase == true {
                    // Check if it's likely a team/player name (not common words)
                    let commonWords = ["who", "will", "win", "game", "tonight", "tomorrow", "today", "the", "what", "when", "how"]
                    if !commonWords.contains(word.lowercased()) {
                        extractedTeam = word
                        print("✅ Found potential team/player: '\(word)'")
                        break
                    }
                }
            }
        }
        
        // Extract time information
        let timeKeywords = ["tonight", "tomorrow", "today", "sunday", "monday", "tuesday",
                           "wednesday", "thursday", "friday", "saturday", "next week", "this week"]
        for keyword in timeKeywords {
            if lowercaseQuestion.contains(keyword) {
                timeInfo = keyword
                print("✅ Found time keyword: '\(keyword)'")
                break
            }
        }
        
        print("🏁 Extraction result - Team: '\(extractedTeam)', Time: '\(timeInfo)'")
        return (extractedTeam, timeInfo)
    }

    // New function to extract sports keywords when no specific team is found
    private func extractSportsKeywords(from question: String) -> String {
        let lowercaseQuestion = question.lowercased()
        
        // Look for sport-specific keywords
        let sportsKeywords = [
            "basketball", "nba", "football", "nfl", "baseball", "mlb", "hockey", "nhl",
            "soccer", "mls", "tennis", "ufc", "mma", "boxing", "golf", "pga"
        ]
        
        for keyword in sportsKeywords {
            if lowercaseQuestion.contains(keyword) {
                return keyword.uppercased()
            }
        }
        
        // Look for general sports terms
        if lowercaseQuestion.contains("game") || lowercaseQuestion.contains("match") {
            return "sports game"
        }
        
        return ""
    }

    private func convertRelativeTimeToDate(_ timeInfo: String) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeInfo.lowercased() {
        case "tonight", "today":
            return now
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: now) ?? now
        case "sunday":
            return getNextWeekday(1, from: now)
        case "monday":
            return getNextWeekday(2, from: now)
        case "tuesday":
            return getNextWeekday(3, from: now)
        case "wednesday":
            return getNextWeekday(4, from: now)
        case "thursday":
            return getNextWeekday(5, from: now)
        case "friday":
            return getNextWeekday(6, from: now)
        case "saturday":
            return getNextWeekday(7, from: now)
        default:
            return now
        }
    }

    private func getNextWeekday(_ weekday: Int, from date: Date) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let daysUntilTarget = (weekday - currentWeekday + 7) % 7
        let targetDate = calendar.date(byAdding: .day, value: daysUntilTarget == 0 ? 7 : daysUntilTarget, to: date) ?? date
        return targetDate
    }

    private func formatDateForSearch(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd yyyy"
        return formatter.string(from: date)
    }

    private func buildSearchQuery(team: String, date: String, question: String) -> String {
        // Determine if this is UFC/MMA, Tennis, or team sports
        let lowercaseQuestion = question.lowercased()
        
        if lowercaseQuestion.contains("ufc") || lowercaseQuestion.contains("mma") || lowercaseQuestion.contains("fight") {
            return "\(team) UFC fight opponent \(date)"
        } else if lowercaseQuestion.contains("tennis") || lowercaseQuestion.contains("match") {
            return "\(team) tennis match opponent \(date)"
        } else {
            // Team sports (baseball, basketball, football, etc.)
            return "\(team) vs game \(date) opponent schedule"
        }
    }

    private func extractOpponentFromSearchResults(searchResults: String, originalTeam: String, targetDate: Date) -> String {
        print("🔍 Searching for opponent in results...")
        let lines = searchResults.components(separatedBy: .newlines)
        
        // Look for various patterns that indicate matchups
        let patterns = ["vs", " v ", "versus", "against", "@", "plays"]
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            print("📋 Checking line: \(line.prefix(100))...")
            
            for pattern in patterns {
                if lowercaseLine.contains(pattern) {
                    if let matchup = extractMatchupFromLine(line: lowercaseLine, pattern: pattern, originalTeam: originalTeam) {
                        print("✅ Found opponent: '\(matchup)'")
                        return matchup
                    }
                }
            }
            
            // Also look for team names in titles and snippets
            if lowercaseLine.contains("title:") || lowercaseLine.contains("content:") {
                if let opponent = extractTeamFromContent(content: lowercaseLine, originalTeam: originalTeam) {
                    print("✅ Found opponent from content: '\(opponent)'")
                    return opponent
                }
            }
        }
        
        print("❌ No opponent found in search results")
        return ""
    }

    private func extractMatchupFromLine(line: String, pattern: String, originalTeam: String) -> String? {
        guard let patternRange = line.range(of: pattern) else { return nil }
        
        let beforePattern = String(line[..<patternRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let afterPattern = String(line[patternRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check which side contains our original team
        let originalTeamWords = originalTeam.lowercased().components(separatedBy: .whitespaces)
        let beforeContainsTeam = originalTeamWords.allSatisfy { beforePattern.lowercased().contains($0) }
        let afterContainsTeam = originalTeamWords.allSatisfy { afterPattern.lowercased().contains($0) }
        
        if beforeContainsTeam {
            return extractCleanTeamName(from: afterPattern)
        } else if afterContainsTeam {
            return extractCleanTeamName(from: beforePattern)
        }
        
        return nil
    }

    private func extractTeamFromContent(content: String, originalTeam: String) -> String? {
        // Look for common team name patterns in the content
        let teamPatterns = [
            "new york", "los angeles", "boston", "chicago", "toronto", "miami", "philadelphia",
            "dallas", "houston", "atlanta", "detroit", "denver", "seattle", "phoenix",
            "yankees", "red sox", "dodgers", "giants", "cubs", "cardinals", "astros",
            "lakers", "warriors", "celtics", "knicks", "heat", "bulls", "spurs",
            "cowboys", "patriots", "steelers", "packers", "49ers", "ravens"
        ]
        
        let contentLower = content.lowercased()
        let originalLower = originalTeam.lowercased()
        
        for pattern in teamPatterns {
            if contentLower.contains(pattern) && !originalLower.contains(pattern) {
                // Found a different team, clean it up and return
                return pattern.capitalized
            }
        }
        
        return nil
    }

    private func extractCleanTeamName(from text: String) -> String {
        // Remove common prefixes and suffixes, extract team name
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count > 2 }
        
        // Look for capitalized team names or known team patterns
        let filteredWords = words.filter { word in
            !["the", "vs", "game", "match", "against", "play", "tonight", "today", "tomorrow"].contains(word.lowercased())
        }
        
        return filteredWords.prefix(2).joined(separator: " ").capitalized
    }

    private func createOptimizedQuestion(
        originalQuestion: String,
        teamInfo: String,
        opponentInfo: String,
        date: Date,
        wordLimit: Int
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let lowercaseOriginal = originalQuestion.lowercased()
        
        // Determine question type and create appropriate format
        var optimizedQuestion: String
        
        if lowercaseOriginal.contains("who will win") || lowercaseOriginal.contains("winner") {
            if !opponentInfo.isEmpty {
                optimizedQuestion = "Who will win: \(teamInfo) vs. \(opponentInfo)? (\(dateString))"
            } else {
                optimizedQuestion = "Who will win the \(teamInfo) game? (\(dateString))"
            }
        } else if lowercaseOriginal.contains("score") || lowercaseOriginal.contains("points") {
            if !opponentInfo.isEmpty {
                optimizedQuestion = "Who will score more: \(teamInfo) vs. \(opponentInfo)? (\(dateString))"
            } else {
                optimizedQuestion = "How many will \(teamInfo) score? (\(dateString))"
            }
        } else if lowercaseOriginal.contains("hits") || lowercaseOriginal.contains("stats") {
            if !opponentInfo.isEmpty {
                optimizedQuestion = "Who will get the most hits: \(teamInfo) vs. \(opponentInfo)? (\(dateString))"
            } else {
                optimizedQuestion = "Who will get the most hits in the \(teamInfo) game? (\(dateString))"
            }
        } else {
            // Generic optimization
            if !opponentInfo.isEmpty {
                optimizedQuestion = "Who will win: \(teamInfo) vs. \(opponentInfo)? (\(dateString))"
            } else {
                optimizedQuestion = "\(teamInfo) game outcome? (\(dateString))"
            }
        }
        
        // Apply word limit
        let words = optimizedQuestion.components(separatedBy: .whitespacesAndNewlines)
        if words.count > wordLimit {
            let truncatedWords = Array(words.prefix(wordLimit))
            optimizedQuestion = truncatedWords.joined(separator: " ")
            if !optimizedQuestion.hasSuffix("?") {
                optimizedQuestion += "?"
            }
        }
        
        return optimizedQuestion
    }

    // Add this new function for enhanced optimization when search fails
    private func createEnhancedOptimization(_ question: String, team: String, date: Date, wordLimit: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let lowercaseOriginal = question.lowercased()
        
        // Create a better question even without opponent info
        var optimizedQuestion: String
        
        if lowercaseOriginal.contains("who will win") || lowercaseOriginal.contains("winner") {
            optimizedQuestion = "Who will win the \(team) game? (\(dateString))"
        } else if lowercaseOriginal.contains("score") || lowercaseOriginal.contains("points") {
            optimizedQuestion = "How many points will \(team) score? (\(dateString))"
        } else if !team.isEmpty {
            optimizedQuestion = "What will happen in the \(team) game? (\(dateString))"
        } else {
            optimizedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
            if !optimizedQuestion.hasSuffix("?") {
                optimizedQuestion += "?"
            }
            optimizedQuestion += " (\(dateString))"
        }
        
        // Apply word limit
        let words = optimizedQuestion.components(separatedBy: .whitespacesAndNewlines)
        if words.count > wordLimit {
            let truncatedWords = Array(words.prefix(wordLimit))
            optimizedQuestion = truncatedWords.joined(separator: " ")
            if !optimizedQuestion.hasSuffix("?") && !optimizedQuestion.contains("(") {
                optimizedQuestion += "?"
            }
        }
        
        return optimizedQuestion
    }

    private func createBasicOptimization(_ question: String, wordLimit: Int) -> String {
        var optimized = question.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Capitalize first letter
        if let firstChar = optimized.first {
            optimized = String(firstChar).uppercased() + String(optimized.dropFirst())
        }
        
        // Add question mark if missing
        if !optimized.hasSuffix("?") {
            optimized += "?"
        }
        
        // Try to add today's date at least
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        if !optimized.contains("(") {
            optimized = optimized.replacingOccurrences(of: "?", with: "") + "? (\(todayString))"
        }
        
        // Apply word limit
        let words = optimized.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if words.count > wordLimit {
            let truncatedWords = Array(words.prefix(wordLimit))
            optimized = truncatedWords.joined(separator: " ")
            if !optimized.hasSuffix("?") && !optimized.contains("(") {
                optimized += "?"
            }
        }
        
        return optimized
    }
}

// New DatePickerView component similar to TimerSetView
struct DatePickerView: View {
    private let pickerViewTitlePadding: CGFloat = 4.0
    
    let title: String
    let range: ClosedRange<Int>
    let binding: Binding<Int>
    let formatter: ((Int) -> String)?
    
    init(title: String, range: ClosedRange<Int>, binding: Binding<Int>, formatter: ((Int) -> String)? = nil) {
        self.title = title
        self.range = range
        self.binding = binding
        self.formatter = formatter
    }
    
    var body: some View {
        HStack(spacing: -pickerViewTitlePadding) {
            Picker(title, selection: binding) {
                ForEach(range, id: \.self) { value in
                    HStack {
                        Spacer()
                        Text(formatter?(value) ?? "\(value)")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .pickerStyle(InlinePickerStyle())
            .labelsHidden()
            
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// Extension to AIServices for category-based bet suggestions with word limit
extension AIServices {
    @available(iOS 15.0, *)
    func generateCategoryBetSuggestions(category: BetCategoryView.BetCategory?, count: Int, betType: String, wordLimit: Int = 100) async throws -> [String] {
        let categoryContext = category?.aiPromptContext ?? "general everyday activities"
        let categoryName = category?.rawValue.lowercased() ?? "general"
        let examples = getSamplePrompts(for: category)
        
        // Define the prompt based on bet type
        let prompt: String
        
        switch betType.lowercased() {
        case "normal":
            prompt = """
            Generate \(count) fun and creative betting questions specifically about \(categoryContext).
            These should be engaging \(categoryName) situations that friends can make bets about.
            
            Focus exclusively on \(categoryContext) and make them:
            - Realistic and achievable
            - Fun for friends to bet on
            - Measurable with clear outcomes
            - Appropriate for social betting
            - Timeless (not dependent on specific dates or events)
            - IMPORTANT: Each question must be under \(wordLimit) words
            
            Examples of \(categoryName) bets include:
            \(examples)
            
            Return only the betting questions, one per line, without numbering or extra text.
            Keep each question concise and under \(wordLimit) words.
            """
            
        case "timed":
            prompt = """
            Generate \(count) fun and creative **timed** betting questions about \(categoryContext).
            These should be challenges where the person must complete something within a limited amount of time,
            but do **not** include any specific time durations in the question.

            Let the user choose the time themselves later in the app.

            Guidelines:
            - Make it clear that the task is time-based
            - Do **not** mention specific times like "2 minutes" or "30 seconds"
            - Use phrases like "quickly", "as fast as you can", or "before time runs out"
            - Keep it fun, achievable, and measurable
            - Avoid any sensitive or unsafe suggestions
            - IMPORTANT: Each question must be under \(wordLimit) words

            Examples:
            - Can you finish a plate of spaghetti before time runs out?
            - Can you build a card tower as fast as you can without it falling?
            - Can you name 20 countries quickly without pausing?

            Return only the betting questions, one per line, no numbering or extra text.
            Keep each question concise and under \(wordLimit) words.
            """
            
        case "contest":
            prompt = """
            Generate \(count) competitive **contest-style** betting questions about \(categoryContext).
            These should be bets where multiple people compete to see **who can do something the fastest or best**.
            
            Focus on:
            - Head-to-head or group competition
            - Clear and measurable outcomes (e.g., time, quantity, quality)
            - Fun for groups of friends
            - Fair and achievable challenges
            - IMPORTANT: Each question must be under \(wordLimit) words
            
            Examples:
            - Who can eat 10 hot dogs the fastest?
            - Who can do the most push-ups in 1 minute?
            
            Return only the betting questions, one per line, no numbering.
            Keep each question concise and under \(wordLimit) words.
            """
            
        default:
            throw NSError(domain: "AIServices", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported bet type: \(betType)"])
        }
        
        let response = try await sendPrompt(
            prompt,
            model: "gemini-2.5-flash-lite",
            temperature: 0.8,
            maxTokens: 400
        )
        
        // Apply word limit to each suggestion
        let suggestions = response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 15 }
            .map { suggestion in
                let words = suggestion.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                if words.count > wordLimit {
                    let truncatedWords = Array(words.prefix(wordLimit))
                    return truncatedWords.joined(separator: " ")
                }
                return suggestion
            }
            .prefix(count)
            .map { String($0) }
        
        return Array(suggestions)
    }
    
    private func getSamplePrompts(for category: BetCategoryView.BetCategory?) -> String {
        guard let category = category else {
            return "everyday random events, social situations, or general predictions"
        }
        
        switch category {
        case .sports:
            return "which team will score first, who will have the most assists, what the final score margin will be"
        case .food:
            return "which restaurant will have the longest wait, who can finish the spiciest dish, what the most popular menu item will be"
        case .lifeEvents:
            return "who will get engaged first, which friend will move cities, who will get promoted this year"
        case .politics:
            return "which candidate will win, what the voter turnout will be, which policy will pass first"
        case .entertainment:
            return "which movie will be released first, who will win an award, what the most popular song will be"
        case .other:
            return "what the weather will be like, which movie will top the box office, who will reply to texts fastest"
        }
    }
}

struct BetOptionsView: View {
    @Binding var navPath: NavigationPath
    let betPrompt: String
    let selectedDate: Date?
    let email: String
    let userId: UUID?
    let optionCount: Int
    let max_selections: Int
    let selectedCategory: BetCategoryView.BetCategory?
    let betType: String
    let timerDays: Int
    let timerHours: Int
    let timerMinutes: Int
    let timerSeconds: Int

    @State private var betOptions: [String] = []
    @State private var betTerms: String = ""
    @State private var isNextActive = false
    @State private var isGeneratingOptions = false
    @State private var isOptimizing = false
    @State private var target = 1
    @State private var isContestAmountPickerEnabled = false
    
    // Options refresh cooldown states - using AppStorage for persistence
    @AppStorage("optionsRefreshCount") private var optionsRefreshCount = 0
    @AppStorage("lastOptionsRefreshTimestamp") private var lastOptionsRefreshTimestamp: Double = 0
    @State private var isOptionsRefreshDisabled = false
    @State private var optionsCooldownTimer: Timer?
    @State private var optionsTimeRemaining: Int = 0
    
    // Terms refresh cooldown states - using AppStorage for persistence
    @AppStorage("termsRefreshCount") private var termsRefreshCount = 0
    @AppStorage("lastTermsRefreshTimestamp") private var lastTermsRefreshTimestamp: Double = 0
    @State private var isTermsRefreshDisabled = false
    @State private var termsCooldownTimer: Timer?
    @State private var termsTimeRemaining: Int = 0
    
    @State private var isTermsEnabled = false
    @State private var effectiveSelectedDate: Date = Date() // Default to today
    
    private let maxRefreshesPerMinute = 3
    
    private var filledOptionsCount: Int {
        betOptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
    
    // Validation computed property
    private var canProceed: Bool {
        let optionsValid = betOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let termsValid = !isTermsEnabled || !betTerms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return optionsValid && termsValid
    }
    
    private let maxWordsInTerms = 300
        
    private func wordCount(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    private var currentWordCount: Int {
        wordCount(in: betTerms)
    }
    
    private var isOverWordLimit: Bool {
        currentWordCount > maxWordsInTerms
    }
    
    private var displayDate: Date {
        // First priority: explicit selectedDate from parent (NormalBetView)
        if let explicitDate = selectedDate {
            return explicitDate
        }
        
        // Second priority: date extracted from terms (if terms are enabled)
        if isTermsEnabled, let extractedDate = extractDateFromTerms(betTerms) {
            return extractedDate
        }
        
        // Third priority: date extracted from bet prompt (using NormalBetView's logic)
        if let promptDate = extractDateFromBetPrompt(betPrompt) {
            return promptDate
        }
        
        // Fallback: today's date
        return effectiveSelectedDate
    }
    
    private func extractDateFromTerms(_ terms: String) -> Date? {
        let dateFormatter = DateFormatter()
        let formats = [
            "MMMM dd, yyyy",     // January 15, 2024
            "MMM dd, yyyy",      // Jan 15, 2024
            "MM/dd/yyyy",        // 01/15/2024
            "M/d/yyyy",          // 1/15/2024
            "yyyy-MM-dd",        // 2024-01-15
            "dd/MM/yyyy",        // 15/01/2024
            "MMMM dd",           // January 15 (current year)
            "MMM dd",            // Jan 15 (current year)
            "MM/dd",             // 01/15 (current year)
            "M/d"                // 1/15 (current year)
        ]
        
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // Remove common words that might interfere with date parsing
        let cleanedTerms = terms.replacingOccurrences(of: "by ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "on ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "until ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "before ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "after ", with: "", options: .caseInsensitive)
        
        for format in formats {
            dateFormatter.dateFormat = format
            dateFormatter.locale = Locale(identifier: "en_US")
            
            // Try to find dates in the text
            let scanner = Scanner(string: cleanedTerms)
            scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines
            
            while !scanner.isAtEnd {
                if let scannedString = scanner.scanUpToCharacters(from: .whitespacesAndNewlines) {
                    if let date = dateFormatter.date(from: scannedString) {
                        // For formats without year, add current year
                        if !format.contains("yyyy") {
                            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                            components.year = currentYear
                            if let dateWithYear = Calendar.current.date(from: components) {
                                return dateWithYear
                            }
                        }
                        return date
                    }
                }
            }
            
            // Also try scanning the entire string for partial matches
            let words = cleanedTerms.components(separatedBy: .whitespacesAndNewlines)
            for word in words {
                if let date = dateFormatter.date(from: word) {
                    if !format.contains("yyyy") {
                        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                        components.year = currentYear
                        if let dateWithYear = Calendar.current.date(from: components) {
                            return dateWithYear
                        }
                    }
                    return date
                }
            }
        }
        
        return nil
    }
    
    private func extractDateFromBetPrompt(_ prompt: String) -> Date? {
        let lowercaseText = prompt.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lowercaseText.contains("tonight") {
            return now
        } else if lowercaseText.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercaseText.contains("sunday") {
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilSunday = (1 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilSunday == 0 ? 7 : daysUntilSunday, to: now)
        } else if lowercaseText.contains("friday") {
            let weekday = calendar.component(.weekday, from: now)
            let daysUntilFriday = (6 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilFriday == 0 ? 7 : daysUntilFriday, to: now)
        }
        // Add other day patterns as needed
        
        return nil
    }

    var body: some View {
        ZStack {
            backgroundGradient
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    categoryAndDateSection
                    
                    if betType == "normal" {
                        optionsHeaderSection
                        optionsListSection
                    }
                    
                    if betType == "contest" {
                        HStack {
                            Text(isContestAmountPickerEnabled ? "Disable Target Score": "Enable Target Score")
                            Spacer()
                            Toggle("", isOn: $isContestAmountPickerEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                        .padding(.horizontal)
                        
                        if isContestAmountPickerEnabled {
                            ContestAmountPicker
                        }
                    }
                    
                    termsHeaderSection
                    
                    if isTermsEnabled {
                        termsEditorSection
                    }
                    
                    Spacer(minLength: 20)
                    
                    aiOptimizationSection
                    navigationLinksSection
                    actionButtonSection
                    validationMessageSection
                }
                .padding(.top)
            }
        }
        .onAppear {
            setupInitialOptions()
            checkOptionsCooldownStatus()
            checkTermsCooldownStatus()
            
            if selectedDate == nil {
                effectiveSelectedDate = Date()
            }
        }
        .onDisappear {
            optionsCooldownTimer?.invalidate()
            termsCooldownTimer?.invalidate()
        }
        
    }

    // MARK: - Extracted View Components
    
    private var ContestAmountPicker: some View {
        Group {
            // Number of Options Section
            VStack(spacing: 12) {
                HStack {
                    Text("Target Goal")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    // Counter/Ticker on the right
                    HStack(spacing: 16) {
                        Button(action: {
                            if target > 1 {
                                target = target - 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(target > 1 ? .blue : .gray)
                                .font(.title2)
                        }
                        .disabled(target <= 1)
                        
                        Text("\(target)")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(minWidth: 30)
                        
                        Button(action: {
                            target += 1
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.15, green: 0.15, blue: 0.25)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var categoryAndDateSection: some View {
        HStack {
            categoryDisplay
            Spacer()
            dateDisplay
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var categoryDisplay: some View {
        if let category = selectedCategory {
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }

    private var dateDisplay: some View {
        Group {
            if let date = selectedDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                    Text("Challenge Date: \(date, style: .date)")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                }
            } else {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(.gray)
                    Text("No specific date")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.subheadline)
                }
            }
        }
    }

    private var optionsHeaderSection: some View {
        VStack(spacing: 8) {
            HStack {
                optionsCounterText
                Spacer()
                generateOptionsButton
            }
            
            // Options cooldown message with live timer
            if isOptionsRefreshDisabled && optionsTimeRemaining > 0 {
                HStack {
                    Spacer()
                    Text("Options cooldown: \(optionsTimeRemaining)s remaining")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Spacer()
                }
            } else if optionsRefreshCount > 0 && !isOptionsRefreshDisabled {
                HStack {
                    Spacer()
                    Text("\(maxRefreshesPerMinute - optionsRefreshCount) option refreshes remaining this minute")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
    }

    private var optionsCounterText: some View {
        HStack(spacing: 0) {
            Text("Options (")
                .foregroundColor(.white)
                .font(.headline)
            Text("\(filledOptionsCount)")
                .foregroundColor(filledOptionsCount == optionCount ? .green : .orange)
                .font(.headline)
            Text(" filled / \(optionCount) required)")
                .foregroundColor(.white)
                .font(.headline)
        }
    }

    private var generateOptionsButton: some View {
        Button {
            Task {
                await handleOptionsRefreshTap()
            }
        } label: {
            Group {
                if isGeneratingOptions {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkles")
                        .foregroundColor(isOptionsRefreshDisabled ? .gray : .yellow)
                        .font(.system(size: 20))
                }
            }
            .padding(8)
            .background((isOptionsRefreshDisabled ? Color.gray : Color.yellow).opacity(0.2))
            .clipShape(Circle())
        }
        .disabled(isGeneratingOptions || isOptionsRefreshDisabled)
    }

    private var optionsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(betOptions.indices, id: \.self) { index in
                    optionRow(at: index)
                }
            }
        }
        .frame(maxHeight: 250)
    }

    private func optionRow(at index: Int) -> some View {
        HStack {
            Text("\(index + 1).")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
            
            TextField("Option \(index + 1)", text: $betOptions[index])
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }

    private var termsHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Terms (Penalties, Prizes, Rules)")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                Spacer()
                Toggle("", isOn: $isTermsEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .frame(width: 40)
                    .padding(.trailing, 16)
            }
            
            if isTermsEnabled {
                HStack {
                    Spacer()
                    generateTermsButton
                }
                
                // Terms cooldown message with live timer
                if isTermsRefreshDisabled && termsTimeRemaining > 0 {
                    HStack {
                        Spacer()
                        Text("Terms cooldown: \(termsTimeRemaining)s remaining")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Spacer()
                    }
                } else if termsRefreshCount > 0 && !isTermsRefreshDisabled {
                    HStack {
                        Spacer()
                        Text("\(maxRefreshesPerMinute - termsRefreshCount) terms refreshes remaining this minute")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.caption)
                        Spacer()
                    }
                }
                
                // Word count indicator
                HStack {
                    Text("Word count: \(currentWordCount) / \(maxWordsInTerms)")
                        .font(.caption)
                        .foregroundColor(isOverWordLimit ? .red : (currentWordCount > maxWordsInTerms * 3/4 ? .orange : .gray))
                    
                    Spacer()
                    
                    if isOverWordLimit {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("Exceeds limit")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var generateTermsButton: some View {
        Button {
            Task {
                await handleTermsRefreshTap()
            }
        } label: {
            Image(systemName: "sparkles")
                .foregroundColor(isTermsRefreshDisabled ? .gray : .yellow)
                .font(.system(size: 20))
                .padding(8)
                .background((isTermsRefreshDisabled ? Color.gray : Color.yellow).opacity(0.2))
                .clipShape(Circle())
        }
        .disabled(isTermsRefreshDisabled)
    }

    private var termsEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Text Editor with word limit enforcement
            TextEditor(text: $betTerms)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isOverWordLimit ? Color.red : Color.clear, lineWidth: 2)
                )
                .onChange(of: betTerms) { newValue in
                    enforceWordLimit(newValue)
                }
            
            // Word limit warning
            if isOverWordLimit {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text("Terms exceed \(maxWordsInTerms) word limit. Text has been automatically truncated.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 4)
            } else if currentWordCount > maxWordsInTerms * 3/4 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Approaching word limit. Consider keeping terms concise.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
    }
    
    private func enforceWordLimit(_ newValue: String) {
        let words = newValue.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // If over the limit, truncate to the word limit
        if words.count > maxWordsInTerms {
            let truncatedWords = Array(words.prefix(maxWordsInTerms))
            let truncatedText = truncatedWords.joined(separator: " ")
            
            // Use a dispatch to avoid binding update conflicts
            DispatchQueue.main.async {
                self.betTerms = truncatedText
            }
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }

    private var aiOptimizationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            optimizationHeader
            
            if isOptimizing {
                optimizationProgress
            }
        }
        .padding(.horizontal)
    }

    private var optimizationHeader: some View {
        HStack {
            Text("AI Optimization")
                .foregroundColor(.white)
                .font(.headline)
            
            Spacer()
            
            optimizeAllButton
        }
    }

    private var optimizeAllButton: some View {
        Button(action: {
            Task {
                await optimizeEverything()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                    .font(.system(size: 16))
                Text("Optimize All")
                    .foregroundColor(.purple)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.2))
            .cornerRadius(8)
        }
        .disabled(!canProceed || isOptimizing)
    }

    private var optimizationProgress: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                .scaleEffect(0.8)
            Text("Optimizing bet, options, and terms...")
                .foregroundColor(.purple.opacity(0.8))
                .font(.caption)
        }
        .padding(.horizontal)
    }

    private var navigationLinksSection: some View {
        NavigationLink(
            destination: finalizeBetDestination,
            isActive: $isNextActive
        ) {
            EmptyView()
        }
        .hidden()
    }

    private var finalizeBetDestination: some View {
        FinalizeBetView(
            navPath: $navPath,
            email: email,
            betPrompt: betPrompt,
            selectedDate: selectedDate,
            betOptions: betOptions,
            betTerms: betTerms,
            betType: betType,
            max_selections: max_selections,
            userId: userId,
            timerDays: timerDays,
            timerHours: timerHours,
            timerMinutes: timerMinutes,
            timerSeconds: timerSeconds,
            target: target,
            isContestAmountPickerEnabled: isContestAmountPickerEnabled,
            isTermsEnabled: isTermsEnabled
        )
    }

    private var actionButtonSection: some View {
        Button(action: {
            if canProceed {
                isNextActive = true
            }
        }) {
            Text("View Summary")
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canProceed ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal)
        .disabled(!canProceed)
    }

    @ViewBuilder
    private var validationMessageSection: some View {
        if !canProceed {
            VStack(alignment: .leading, spacing: 4) {
                if betType == "normal" && betOptions.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    Text("• Please fill out all bet options")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if isTermsEnabled && betTerms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("• Please add terms and conditions")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if isTermsEnabled && isOverWordLimit {
                    Text("• Terms exceed \(maxWordsInTerms) word limit (\(currentWordCount) words)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Refresh Limit Helper Functions
    
    private func getCurrentTimestamp() -> Double {
        return Date().timeIntervalSince1970
    }
    
    // Options cooldown functions
    private func checkOptionsCooldownStatus() {
        let currentTime = getCurrentTimestamp()
        let timeSinceLastRefresh = currentTime - lastOptionsRefreshTimestamp
        
        // Reset if more than 60 seconds have passed
        if timeSinceLastRefresh >= 60 {
            optionsRefreshCount = 0
            isOptionsRefreshDisabled = false
            optionsTimeRemaining = 0
            optionsCooldownTimer?.invalidate()
            return
        }
        
        // Check if we're in cooldown
        if optionsRefreshCount >= maxRefreshesPerMinute {
            isOptionsRefreshDisabled = true
            optionsTimeRemaining = max(0, Int(60 - timeSinceLastRefresh))
            startOptionsLiveTimer()
        } else {
            isOptionsRefreshDisabled = false
            optionsTimeRemaining = 0
        }
    }
    
    private func startOptionsLiveTimer() {
        optionsCooldownTimer?.invalidate()
        
        optionsCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let currentTime = getCurrentTimestamp()
                let timeSinceLastRefresh = currentTime - lastOptionsRefreshTimestamp
                
                if timeSinceLastRefresh >= 60 {
                    // Cooldown period has ended
                    optionsRefreshCount = 0
                    isOptionsRefreshDisabled = false
                    optionsTimeRemaining = 0
                    optionsCooldownTimer?.invalidate()
                } else {
                    // Update remaining time
                    optionsTimeRemaining = max(0, Int(60 - timeSinceLastRefresh))
                    if optionsTimeRemaining == 0 {
                        optionsRefreshCount = 0
                        isOptionsRefreshDisabled = false
                        optionsCooldownTimer?.invalidate()
                    }
                }
            }
        }
    }
    
    private func handleOptionsRefreshTap() async {
        let currentTime = getCurrentTimestamp()
        let timeSinceLastRefresh = currentTime - lastOptionsRefreshTimestamp
        
        // Reset counter if more than 60 seconds have passed
        if timeSinceLastRefresh >= 60 {
            optionsRefreshCount = 0
        }
        
        // Check if we've exceeded the limit
        if optionsRefreshCount >= maxRefreshesPerMinute {
            isOptionsRefreshDisabled = true
            optionsTimeRemaining = max(0, Int(60 - timeSinceLastRefresh))
            startOptionsLiveTimer()
            return
        }
        
        // Increment counter and refresh
        optionsRefreshCount += 1
        lastOptionsRefreshTimestamp = currentTime
        await generateOptions(betPrompt: betPrompt, date: displayDate)
        
        // Start cooldown if we've hit the limit
        if optionsRefreshCount >= maxRefreshesPerMinute {
            isOptionsRefreshDisabled = true
            optionsTimeRemaining = 60
            startOptionsLiveTimer()
        }
    }
    
    // Terms cooldown functions
    private func checkTermsCooldownStatus() {
        let currentTime = getCurrentTimestamp()
        let timeSinceLastRefresh = currentTime - lastTermsRefreshTimestamp
        
        // Reset if more than 60 seconds have passed
        if timeSinceLastRefresh >= 60 {
            termsRefreshCount = 0
            isTermsRefreshDisabled = false
            termsTimeRemaining = 0
            termsCooldownTimer?.invalidate()
            return
        }
        
        // Check if we're in cooldown
        if termsRefreshCount >= maxRefreshesPerMinute {
            isTermsRefreshDisabled = true
            termsTimeRemaining = max(0, Int(60 - timeSinceLastRefresh))
            startTermsLiveTimer()
        } else {
            isTermsRefreshDisabled = false
            termsTimeRemaining = 0
        }
    }
    
    private func startTermsLiveTimer() {
        termsCooldownTimer?.invalidate()
        
        termsCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let currentTime = getCurrentTimestamp()
                let timeSinceLastRefresh = currentTime - lastTermsRefreshTimestamp
                
                if timeSinceLastRefresh >= 60 {
                    // Cooldown period has ended
                    termsRefreshCount = 0
                    isTermsRefreshDisabled = false
                    termsTimeRemaining = 0
                    termsCooldownTimer?.invalidate()
                } else {
                    // Update remaining time
                    termsTimeRemaining = max(0, Int(60 - timeSinceLastRefresh))
                    if termsTimeRemaining == 0 {
                        termsRefreshCount = 0
                        isTermsRefreshDisabled = false
                        termsCooldownTimer?.invalidate()
                    }
                }
            }
        }
    }
    
    private func handleTermsRefreshTap() async {
        let currentTime = getCurrentTimestamp()
        let timeSinceLastRefresh = currentTime - lastTermsRefreshTimestamp
        
        // Reset counter if more than 60 seconds have passed
        if timeSinceLastRefresh >= 60 {
            termsRefreshCount = 0
        }
        
        // Check if we've exceeded the limit
        if termsRefreshCount >= maxRefreshesPerMinute {
            isTermsRefreshDisabled = true
            termsTimeRemaining = max(0, Int(60 - timeSinceLastRefresh))
            startTermsLiveTimer()
            return
        }
        
        // Increment counter and refresh
        termsRefreshCount += 1
        lastTermsRefreshTimestamp = currentTime
        generateTerms(date: displayDate)
        
        // Start cooldown if we've hit the limit
        if termsRefreshCount >= maxRefreshesPerMinute {
            isTermsRefreshDisabled = true
            termsTimeRemaining = 60
            startTermsLiveTimer()
        }
    }

    // MARK: - Helper Functions

    private func setupInitialOptions() {
        if betOptions.isEmpty {
            betOptions = Array(repeating: "", count: optionCount)
            Task {
                await generateOptions(betPrompt: betPrompt, date: displayDate)
            }
        }
    }

    @MainActor
    func optimizeEverything() async {
        isOptimizing = true
        
        do {
            let categoryContext = selectedCategory?.aiPromptContext ?? "general activities"
            let categoryName = selectedCategory?.rawValue.lowercased() ?? "general"
            
            // Optimize the bet question
            let questionPrompt = """
            Optimize this betting question for clarity and engagement: "\(betPrompt)"
            
            This is a \(categoryName) category bet. Make it more specific, measurable, and engaging while keeping the core intent.
            Return only the optimized question.
            """
            
            let optimizedQuestion = try await AIServices.shared.sendPrompt(
                questionPrompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.7,
                maxTokens: 200
            )
            
            // Optimize the options
            let optionsPrompt = """
            For this betting question: "\(optimizedQuestion.trimmingCharacters(in: .whitespacesAndNewlines))"
            
            Generate \(optionCount) optimized, specific options that are:
            - Clear and measurable
            - Mutually exclusive
            - Realistic for \(categoryContext)
            - More engaging than generic options
            
            Return exactly \(optionCount) options, one per line, no numbering.
            """
            
            let optimizedOptionsText = try await AIServices.shared.sendPrompt(
                optionsPrompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.5,
                maxTokens: 300
            )
            
            let optimizedOptionsArray = optimizedOptionsText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(optionCount)
            
            // Optimize the terms
            let termsPrompt = """
            Generate optimized, well-formatted terms for a \(categoryName) bet with these details:
            - Question: \(optimizedQuestion.trimmingCharacters(in: .whitespacesAndNewlines))
            - Options: \(Array(optimizedOptionsArray).joined(separator: ", "))
            - Max selections per user: \(max_selections)
            
            Make the terms clear, fair, and engaging. Use proper formatting with bold text and sections.
            """
            
            let optimizedTerms = try await AIServices.shared.sendPrompt(
                termsPrompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.6,
                maxTokens: 600
            )
            
            // Update all fields
            // Note: We can't update betPrompt here since it's let, but we'll update what we can
            for (index, option) in optimizedOptionsArray.enumerated() {
                if index < betOptions.count {
                    betOptions[index] = option
                }
            }
            betTerms = optimizedTerms.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch {
            print("Failed to optimize everything: \(error)")
        }
        
        isOptimizing = false
    }
    
    func generateOptions(betPrompt: String, date: Date?) async {
        isGeneratingOptions = true
        
        do {
            let isBinaryBet = detectBinaryBet(betPrompt)
            let targetCount = isBinaryBet ? 2 : optionCount
            
            let categoryContext = selectedCategory?.aiPromptContext ?? "general activities"
            
            let prompt: String
            
            if isBinaryBet {
                prompt = """
                Analyze this betting question: "\(betPrompt)"
                
                This is a binary (yes/no or either/or) question in the \(selectedCategory?.rawValue.lowercased() ?? "general") category.
                
                Generate exactly 2 clear, specific options that directly answer this question:
                
                Rules:
                - Extract the exact entities/teams/people mentioned in the question
                - If it's "Who will win X vs Y", return exactly "X" and "Y" (use the actual names)
                - If it's "Will [something] happen", return "Yes" and "No"
                - If it's "Which is better A or B", return "A" and "B" (use actual names)
                - Be precise and use the exact terms from the question
                - Keep each option under 8 words
                
                Return only the 2 options, one per line, no numbering or extra text.
                """
            } else {
                // Modified prompt to exclude date context when no date is selected
                let dateContext: String
                if let date = date {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .full
                    let formattedDate = dateFormatter.string(from: date)
                    dateContext = "- Make them realistic for the date: \(formattedDate)"
                } else {
                    dateContext = "- Make them generally realistic and timeless (no specific date context needed)"
                }
                
                prompt = """
                Analyze this betting question: "\(betPrompt)"
                
                Generate exactly \(targetCount) realistic, specific options that directly answer this question about \(categoryContext).
                
                Requirements:
                - Each option must be a plausible answer to the exact question asked
                - Be specific and measurable (avoid vague terms like "other" or "something else")
                - If the question mentions specific entities, include them in relevant options
                - Options should be mutually exclusive (only one can be correct)
                \(dateContext)
                - Keep each option concise (under 15 words)
                - Ensure all \(targetCount) options are filled
                
                For example:
                - If asked "What will the weather be like?": "Sunny", "Rainy", "Cloudy", "Stormy"
                - If asked "Who will score first?": Use actual player names if mentioned
                - If asked "What time will we arrive?": "Before 2 PM", "2-4 PM", "4-6 PM", "After 6 PM"
                
                Return exactly \(targetCount) options, one per line, no numbering or extra text.
                """
            }

            let responseText = try await AIServices.shared.sendPrompt(
                prompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.3,
                maxTokens: 300
            )

            let cleanedLines = responseText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map {
                    // Remove numbering, bullets, and other prefixes
                    $0.replacingOccurrences(of: #"^\s*[\d\-\•\*\)\.\:]+\.?\s*"#, with: "", options: .regularExpression)
                }
                .filter { $0.count > 1 && $0.count < 150 }

            var generatedOptions = Array(cleanedLines.prefix(targetCount))
            
            // Ensure we have the exact number of options needed
            while generatedOptions.count < targetCount {
                let fallbackOptions = generateFallbackOptions(for: betPrompt, isBinary: isBinaryBet, count: targetCount - generatedOptions.count)
                generatedOptions.append(contentsOf: fallbackOptions)
            }
            
            // Take exactly the number we need
            generatedOptions = Array(generatedOptions.prefix(targetCount))
            
            // Clear existing options and fill with generated ones
            betOptions = Array(repeating: "", count: optionCount)
            for (index, option) in generatedOptions.enumerated() {
                if index < betOptions.count {
                    betOptions[index] = option
                }
            }

            // If we still don't have enough, use fallback
            if generatedOptions.count < targetCount {
                let additionalFallback = generateFallbackOptions(for: betPrompt, isBinary: isBinaryBet, count: targetCount)
                for (index, option) in additionalFallback.enumerated() {
                    if index < betOptions.count && betOptions[index].isEmpty {
                        betOptions[index] = option
                    }
                }
            }

        } catch {
            print("Failed to generate bet options: \(error)")
            let fallbackOptions = generateFallbackOptions(for: betPrompt, isBinary: detectBinaryBet(betPrompt), count: optionCount)
            betOptions = Array(repeating: "", count: optionCount)
            for (index, option) in fallbackOptions.enumerated() {
                if index < betOptions.count {
                    betOptions[index] = option
                }
            }
        }
        
        isGeneratingOptions = false
    }

    func detectBinaryBet(_ prompt: String) -> Bool {
        let lowercased = prompt.lowercased()
        
        let binaryKeywords = [
            "who will win", "vs", " v ", " or ", "will there be", "will it", "yes or no",
            "true or false", "happen or not", "over or under", "better", "worse",
            "will they", "will he", "will she", "does", "is it", "can they", "should"
        ]
        
        let versusPatterns = [
            " vs?\\.? ",
            " versus ",
            "\\b\\w+ or \\w+\\b",
            " vs$ ",
            "\\bversus\\b"
        ]
        
        for keyword in binaryKeywords {
            if lowercased.contains(keyword) {
                return true
            }
        }
        
        for pattern in versusPatterns {
            if lowercased.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    func generateFallbackOptions(for prompt: String, isBinary: Bool, count: Int) -> [String] {
        if isBinary {
            let lowercased = prompt.lowercased()
            
            // Try to extract specific entities from vs/versus patterns
            if let vsRange = lowercased.range(of: " vs ") ?? lowercased.range(of: " versus ") ?? lowercased.range(of: " v ") {
                let beforeVs = String(lowercased[..<vsRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let afterVs = String(lowercased[vsRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let lastWord = beforeVs.components(separatedBy: " ").last?.capitalized,
                   let firstWord = afterVs.components(separatedBy: " ").first?.capitalized,
                   !lastWord.isEmpty && !firstWord.isEmpty {
                    return [lastWord, firstWord]
                }
            }
            
            // Check for "will" questions
            if lowercased.contains("will") {
                return ["Yes", "No"]
            }
            
            // Check for choice questions
            if lowercased.contains(" or ") {
                let parts = lowercased.components(separatedBy: " or ")
                if parts.count >= 2 {
                    let option1 = parts[0].components(separatedBy: " ").last?.capitalized ?? "Option A"
                    let option2 = parts[1].components(separatedBy: " ").first?.capitalized ?? "Option B"
                    return [option1, option2]
                }
            }
            
            return ["Yes", "No"]
        } else {
            // Non-binary bet fallback options
            guard let category = selectedCategory else {
                let baseOptions = [
                    "Most likely outcome",
                    "Second most likely",
                    "Unexpected result",
                    "Long shot possibility",
                    "Alternative scenario",
                    "Dark horse option",
                    "Wildcard choice",
                    "Backup possibility",
                    "Outside chance",
                    "Final option"
                ]
                return Array(baseOptions.prefix(count))
            }
            
            let categoryOptions: [String] = {
                switch category {
                case .sports:
                    return [
                        "Home team wins",
                        "Away team wins",
                        "Game goes to overtime",
                        "Under total score",
                        "Over total score",
                        "First half leader",
                        "Most fouls",
                        "Fastest goal",
                        "Defensive play",
                        "Surprise outcome"
                    ]
                case .food:
                    return [
                        "Spicy option",
                        "Sweet choice",
                        "Healthy alternative",
                        "Comfort food",
                        "New cuisine",
                        "Local favorite",
                        "Chef's special",
                        "Vegetarian option",
                        "Popular choice",
                        "Unique dish"
                    ]
                case .lifeEvents:
                    return [
                        "Within a month",
                        "Within 6 months",
                        "By end of year",
                        "Next year",
                        "Sooner than expected",
                        "Later than planned",
                        "Exactly on time",
                        "With celebration",
                        "Quietly",
                        "Unexpected timing"
                    ]
                case .politics:
                    return [
                        "Incumbent wins",
                        "Challenger wins",
                        "Close margin",
                        "Landslide victory",
                        "High turnout",
                        "Low turnout",
                        "Policy passes",
                        "Policy fails",
                        "Delayed decision",
                        "Surprise outcome"
                    ]
                case .entertainment:
                    return [
                        "Box office hit",
                        "Surprise cameo",
                        "New season drop",
                        "Plot twist",
                        "Award winner",
                        "Fan favorite",
                        "Streaming debut",
                        "Cancelled show",
                        "Chart-topping song",
                        "Viral moment"
                    ]
                case .other:
                    return [
                        "Most likely outcome",
                        "Second choice",
                        "Unexpected result",
                        "Popular option",
                        "Unique possibility",
                        "Traditional choice",
                        "Modern alternative",
                        "Safe bet",
                        "Risky option",
                        "Wild card"
                    ]
                }
            }()
            
            return Array(categoryOptions.prefix(count))
        }
    }

    func generateTerms(date: Date?) {
        Task {
            do {
                let validOptions = betOptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                let betDescription = validOptions.joined(separator: ", ")
                
                let categoryContext = selectedCategory?.aiPromptContext ?? "general activities"
                let categoryName = selectedCategory?.rawValue.lowercased() ?? "general"
                
                // Conditionally include date context - don't mention date if none is selected
                let dateContext: String
                if let date = date {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .full
                    let formattedDate = dateFormatter.string(from: date)
                    dateContext = "scheduled for \(formattedDate)"
                } else {
                    dateContext = "with no specific timeline or deadline"
                }
                
                let prompt = """
                Generate concise, well-structured terms and conditions for a \(categoryName) bet \(dateContext) 
                involving these options: \(betDescription).
                
                CRITICAL REQUIREMENTS:
                - Each participant can select MAXIMUM \(max_selections) option(s) from \(betOptions.count) total options
                - Keep response under \(maxWordsInTerms) words total (STRICT LIMIT)
                - Use clear, simple language (no legal jargon)
                - Make selection limits impossible to miss
                
                REQUIRED STRUCTURE (use these exact section headers):
                
                ## 🎯 SELECTION RULES
                [Prominently emphasize the \(max_selections) selection limit using bold text and caps]
                
                ## 📋 BET OVERVIEW  
                [Brief description of what this bet covers and timeline]
                
                ## 🏆 WINNING CONDITIONS
                [How winners are determined - keep to 2-3 sentences max]
                
                ## ⚖️ DISPUTE RESOLUTION
                [Simple process for disagreements - 1-2 sentences]
                
                ## 🎉 OUTCOMES
                [What happens to winners/losers - keep brief]
                
                FORMATTING REQUIREMENTS:
                - Use **bold** for critical rules
                - Use CAPITAL LETTERS for the selection limit
                - Use bullet points where helpful
                - Include emojis for section headers as shown
                - Keep each section to 2-4 sentences maximum
                
                Context: This is a \(categoryContext) bet. Include relevant considerations for this category.
                
                WORD LIMIT: Absolute maximum \(maxWordsInTerms) words. Be extremely concise but comprehensive.
                """
                
                let responseText = try await AIServices.shared.sendPrompt(
                    prompt,
                    model: "gemini-2.5-flash",
                    temperature: 0.6,
                    maxTokens: 400  // Further reduced to encourage brevity
                )
                
                let cleanedTerms = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Double-check word count and truncate if necessary
                let generatedWordCount = wordCount(in: cleanedTerms)
                if generatedWordCount > maxWordsInTerms {
                    let words = cleanedTerms.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                    let truncatedWords = Array(words.prefix(maxWordsInTerms))
                    betTerms = truncatedWords.joined(separator: " ")
                } else {
                    betTerms = cleanedTerms
                }
                
            } catch {
                print("Failed to generate bet terms: \(error)")
                
                // Improved category-specific fallback terms with word limit consideration
                let categorySpecificTerms = getStructuredFallbackTerms(date: date)
                let fallbackWordCount = wordCount(in: categorySpecificTerms)
                
                if fallbackWordCount > maxWordsInTerms {
                    let words = categorySpecificTerms.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                    let truncatedWords = Array(words.prefix(maxWordsInTerms))
                    betTerms = truncatedWords.joined(separator: " ")
                } else {
                    betTerms = categorySpecificTerms
                }
            }
        }
    }
    
    private func getStructuredFallbackTerms(date: Date?) -> String {
        let dateContext: String
        if let date = date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let formattedDate = dateFormatter.string(from: date)
            dateContext = "for \(formattedDate)"
        } else {
            dateContext = ""
        }
        
        let categoryName = selectedCategory?.rawValue ?? "General"
        let maxSelections = max_selections
        let totalOptions = betOptions.count
        
        return """
        ## 🎯 SELECTION RULES
        **MAXIMUM \(maxSelections) SELECTION(S) ALLOWED** - Each participant must choose exactly \(maxSelections) option(s) from the \(totalOptions) available choices. **NO MORE, NO LESS.**
        
        ## 📋 BET OVERVIEW
        This is a \(categoryName.lowercased()) bet \(dateContext). All participants agree to the outcome determination process and accept the results as final.
        
        ## 🏆 WINNING CONDITIONS  
        Winners are determined by which selected option(s) prove correct based on official results or group consensus. Partial credit may apply for multiple-selection bets.
        
        ## ⚖️ DISPUTE RESOLUTION
        Disagreements will be resolved by group vote or reference to official sources. The majority decision is binding.
        
        ## 🎉 OUTCOMES
        Winners receive bragging rights and any agreed-upon rewards. Losers accept the results gracefully and fulfill any agreed consequences.
        """
    }
    
    private func getCategoryFallbackTerms(date: Date?) -> String {
        let dateString: String
        if let date = date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateString = dateFormatter.string(from: date)
        } else {
            dateString = "no specific deadline"
        }
        
        let selectionRule = max_selections == 1 ?
            "**⚠️ IMPORTANT: Each participant must select EXACTLY 1 OPTION only.**" :
            "**⚠️ CRITICAL RULE: Each participant can select UP TO \(max_selections) OPTIONS out of \(betOptions.count) total options. NO MORE THAN \(max_selections) SELECTIONS ALLOWED.**"
        
        guard let category = selectedCategory else {
            return """
            ## **SELECTION RULES**
            \(selectionRule)
            
            ## **BET DETAILS**
            • Bet is valid with \(dateString)
            • All participants must confirm their selections before the bet begins
            
            ## **DETERMINATION OF RESULTS**
            • Results will be determined based on the agreed upon criteria
            • Evidence must be clear and verifiable
            
            ## **DISPUTE RESOLUTION**
            • In case of disputes, the majority vote of participants will determine the outcome
            • All participants must agree to accept the group decision
            
            ## **CONSEQUENCES & REWARDS**
            • Winner gets bragging rights and small prize from the group
            • Have fun and bet responsibly!
            """
        }
        
        let baseTerms: String
        switch category {
        case .sports:
            baseTerms = """
            ## **SELECTION RULES**
            \(selectionRule)
            
            ## **BET DETAILS**
            • **Sports bet** valid with \(dateString)
            • All participants must lock in predictions **BEFORE** the event starts
            • Late entries will not be accepted
            
            ## **DETERMINATION OF RESULTS**
            • Results determined by **official game/match outcomes only**
            • Official statistics and scores will be used as final authority
            • No arguing with the refs or official results!
            
            ## **DISPUTE RESOLUTION**
            • Disputes resolved using official statistics and verified sports sources
            • In case of game cancellation or postponement, bet extends to rescheduled date
            • Rain delays or technical issues don't void the bet
            
            ## **CONSEQUENCES & REWARDS**
            • **Winner:** Gets bragging rights and group buys them drinks/snacks
            • **Loser:** Treats the group to next game day snacks
            • Keep it fun and friendly - it's just a game!
            """
        case .food:
            baseTerms = """
            ## **SELECTION RULES**
            \(selectionRule)
            
            ## **BET DETAILS**
            • **Food bet** valid with \(dateString)
            • All participants must confirm predictions before the meal/event
            • No changing minds once the order is placed!
            
            ## **DETERMINATION OF RESULTS**
            • Results determined by **actual choices made** or outcomes achieved
            • Taste tests must be conducted fairly with all participants present
            • Photo evidence may be required for verification
            
            ## **DISPUTE RESOLUTION**
            • Disputes resolved by group consensus or neutral taste tester
            • Restaurant staff can be consulted for verification if needed
            • Keep it light-hearted - we're here to enjoy good food!
            
            ## **CONSEQUENCES & REWARDS**
            • **Winner:** Gets to pick the next restaurant or meal choice
            • **Loser:** Pays for the meal or treats everyone to dessert
            • Bon appétit and may the best palate win!
            """
        case .lifeEvents:
            baseTerms = """
            ## **SELECTION RULES**
            \(selectionRule)
            
            ## **BET DETAILS**
            • **Life events bet** valid with \(dateString)
            • All participants must confirm predictions before any relevant deadlines
            • **RESPECT PRIVACY** - no pressure on anyone to rush life decisions
            
            ## **DETERMINATION OF RESULTS**
            • Results determined by **actual life events** as they naturally occur
            • Verification through social media, mutual friends, or direct confirmation
            • Personal milestones must be publicly shared or confirmed
            
            ## **DISPUTE RESOLUTION**
            • Respect everyone's privacy and personal timeline
            • No pushing people to make life decisions for betting purposes
            • Group consensus on verification methods
            
            ## **CONSEQUENCES & REWARDS**
            • **Winner:** Gets bragging rights and celebration dinner from the group
            • **Celebration:** Group celebrates the actual life event regardless of bet outcome
            • Life is about the journey, not just the bets!
            """
        case .politics:
            baseTerms = """
            ## **SELECTION RULES**
            \(selectionRule)
            
            ## **BET DETAILS**
            • **Political bet** valid with \(dateString)
            • All participants must confirm predictions before voting/announcement deadlines
            • **KEEP DISCUSSIONS RESPECTFUL** regardless of political affiliations
            
            ## **DETERMINATION OF RESULTS**
            • Results determined by **official election results** or policy announcements
            • Only verified, official government sources will be accepted
            • Preliminary results don't count - wait for official certification
            
            ## **DISPUTE RESOLUTION**
            • Disputes resolved using official government sources and verified news outlets
            • Multiple reputable sources required for confirmation
            • Respect different political viewpoints throughout the process
            
            ## **CONSEQUENCES & REWARDS**
            • **Winner:** Gets to choose the next group discussion topic (keep it civil!)
            • **Everyone:** Celebrates democracy in action regardless of outcomes
            • Politics aside, we're all friends here!
            """
        case .entertainment:
            baseTerms = """
            ## **SELECTION RULES**
            \(selectionRule)
            
            ## **BET DETAILS**
            • **Entertainment bet** valid with \(dateString)
            • All participants must lock in predictions before event/show/release begins
            • No spoilers allowed - keep predictions secret until results!
            
            ## **DETERMINATION OF RESULTS**
            • Results determined by **official announcements, releases, or publicly verifiable outcomes**
            • Award shows, box office numbers, streaming platform data, or verified social media
            • Nielsen ratings, Billboard charts, or other industry-standard metrics
            
            ## **DISPUTE RESOLUTION**
            • Disputes resolved using reputable entertainment news sources
            • Platform statistics (Netflix, Spotify, etc.) will be considered official
            • Multiple entertainment news sources required for major disputes
            
            ## **CONSEQUENCES & REWARDS**
            • **Winner:** Picks the next movie night or group's binge-watching show
            • **Loser:** Provides popcorn and drinks for the next entertainment session
            • May the best entertainment taste win!
            """
        case .other:
            baseTerms = """
            ## **SELECTION RULES**
            \(selectionRule)
            
            ## **BET DETAILS**
            • **General bet** valid with \(dateString)
            • All participants must confirm selections before any event/deadline
            • Clear criteria must be established for what constitutes a "win"
            
            ## **DETERMINATION OF RESULTS**
            • Results determined based on **observable, verifiable outcomes**
            • Evidence must be clear and agreed upon by all participants
            • Photo/video evidence may be required for verification
            
            ## **DISPUTE RESOLUTION**
            • In case of disputes, majority vote or neutral observer determines outcome
            • All participants must agree to the verification method beforehand
            • Keep it fun and don't take it too seriously!
            
            ## **CONSEQUENCES & REWARDS**
            • **Winner:** Gets bragging rights and small prize from the group
            • **Everyone:** Has fun and enjoys the friendly competition
            • Remember: it's all about the experience, not just winning!
            """
        }
        
        return baseTerms
    }
}

// Extension to AIServices for category-based bet suggestions
extension AIServices {
    @available(iOS 15.0, *)
    func generateCategoryBetSuggestions(category: BetCategoryView.BetCategory?, count: Int, betType: String) async throws -> [String] {
        let categoryContext = category?.aiPromptContext ?? "general everyday activities"
        let categoryName = category?.rawValue.lowercased() ?? "general"
        let examples = getSamplePrompts(for: category)
        
        // Define the prompt based on bet type
        let prompt: String
        
        switch betType.lowercased() {
        case "normal":
            prompt = """
            Generate \(count) fun and creative betting questions specifically about \(categoryContext).
            These should be engaging \(categoryName) situations that friends can make bets about.
            
            Focus exclusively on \(categoryContext) and make them:
            - Realistic and achievable
            - Fun for friends to bet on
            - Measurable with clear outcomes
            - Appropriate for social betting
            - Timeless (not dependent on specific dates or events)
            
            Examples of \(categoryName) bets include:
            \(examples)
            
            Return only the betting questions, one per line, without numbering or extra text.
            """
            
        case "timed":
            prompt = """
            Generate \(count) fun and creative **timed** betting questions about \(categoryContext).
            These should be challenges where the person must complete something within a limited amount of time,
            but do **not** include any specific time durations in the question.

            Let the user choose the time themselves later in the app.

            Guidelines:
            - Make it clear that the task is time-based
            - Do **not** mention specific times like "2 minutes" or "30 seconds"
            - Use phrases like "quickly", "as fast as you can", or "before time runs out"
            - Keep it fun, achievable, and measurable
            - Avoid any sensitive or unsafe suggestions

            Examples:
            - Can you finish a plate of spaghetti before time runs out?
            - Can you build a card tower as fast as you can without it falling?
            - Can you name 20 countries quickly without pausing?

            Return only the betting questions, one per line, no numbering or extra text.
            """
            
        case "contest":
            prompt = """
            Generate \(count) competitive **contest-style** betting questions about \(categoryContext).
            These should be bets where multiple people compete to see **who can do something the fastest or best**.
            
            Focus on:
            - Head-to-head or group competition
            - Clear and measurable outcomes (e.g., time, quantity, quality)
            - Fun for groups of friends
            - Fair and achievable challenges
            
            Examples:
            - Who can eat 10 hot dogs the fastest?
            - Who can do the most push-ups in 1 minute?
            
            Return only the betting questions, one per line, no numbering.
            """
            
        default:
            throw NSError(domain: "AIServices", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported bet type: \(betType)"])
        }
        
        let response = try await sendPrompt(
            prompt,
            model: "gemini-2.5-flash-lite",
            temperature: 0.8,
            maxTokens: 400
        )
        
        return response
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 15 }
            .prefix(count)
            .map { String($0) }
    }
    
}

struct FinalizeBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let betPrompt: String
    let selectedDate: Date? // Now optional
    let betOptions: [String]
    let betTerms: String
    let betType: String
    let max_selections: Int
    let userId: UUID?
    let timerDays: Int
    let timerHours: Int
    let timerMinutes: Int
    let timerSeconds: Int
    let target: Int
    let isContestAmountPickerEnabled: Bool
    let isTermsEnabled: Bool

    @State private var party_name: String = ""
    @State private var privacy: String = "Open" // Set default to "Open"
    @State private var max_members: Int = 2
    @State private var terms: String = ""
    @State private var isSubmitting = false
    @State private var showPartyDetails = false
    @State private var createdPartyCode: String = ""
    @State private var errorMessage: String = ""
    
    @Environment(\.supabaseClient) private var supabaseClient
    
    private let maxWordsInTerms = 300
    private let maxPartyNameCharacters = 25
    
    private func wordCount(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    private var currentWordCount: Int {
        wordCount(in: betTerms)
    }
    
    private var isOverWordLimit: Bool {
        currentWordCount > maxWordsInTerms
    }
    
    // Validation computed property - privacy is now mandatory
    private var canProceed: Bool {
        let hasValidOptions = betOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasValidTerms = !isTermsEnabled || !betTerms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isWithinWordLimit = !isOverWordLimit // Add word limit check
        
        return hasValidOptions && hasValidTerms && isWithinWordLimit
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                VStack {
                    customHeaderView // Add this line if you want the custom header
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            dateSection
                            betSummarySection
                            partyNameSection
                            privacySection
                            maxMembersSection
                            errorSection
                            submitButtonSection
                            validationSection
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationBarHidden(true) // Hide the default navigation bar if using custom header
        }
        .navigationDestination(isPresented: $showPartyDetails) {
            PartyDetailsView(party_code: createdPartyCode, email: email)
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.15, green: 0.15, blue: 0.25)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var dateSection: some View {
        Group {
            if let date = selectedDate {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Challenge Date")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                        Text(date, style: .date)
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            } else {
                HStack {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundColor(.gray)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("Challenge Timing")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                        Text("No specific date set")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var betSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Challenge Summary")
                .foregroundColor(.white)
                .font(.title)
                .fontWeight(.bold)
            
            partyDetailsCard
            betQuestionCard
            
            // Show options only for "normal" bet type
            if betType == "normal" {
                optionsCard
            }
            
            termsCard
        }
        .padding(.horizontal)
    }
    
    private var partyDetailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Party Details", systemImage: "person.3.fill")
                .foregroundColor(.blue)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Name:")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                    Text(party_name.isEmpty ? "Not set" : party_name)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Privacy:")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                    Text(privacy)
                        .foregroundColor(.blue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Max Members:")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                    Text("\(max_members)")
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Challenge Type:")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                    Text(betType.capitalized)
                        .foregroundColor(.orange)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                if isContestAmountPickerEnabled {
                    HStack {
                        Text("Target Score:")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.subheadline)
                        Text("\(target)")
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var betQuestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Challenge Question", systemImage: "questionmark.circle.fill")
                .foregroundColor(.green)
                .font(.headline)
            
            Text(betPrompt)
                .foregroundColor(.white)
                .font(.system(size: 16))
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Options (\(betOptions.count))", systemImage: "list.bullet")
                .foregroundColor(.orange)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(betOptions.enumerated()), id: \.offset) { index, option in
                    if !option.isEmpty {
                        HStack {
                            Text("\(index + 1).")
                                .foregroundColor(.orange)
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 20)
                            Text(option)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            HStack {
                Text("Max Selections per User:")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                Text("\(max_selections) out of \(betOptions.count)")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
    }
    
    private var termsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Terms Summary", systemImage: "doc.text")
                .foregroundColor(.purple)
                .font(.headline)
            
            ScrollView {
                Text(betTerms.isEmpty ? "No terms set" : betTerms)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(nil)
            }
            .frame(maxHeight: 100)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            // Add word count display
            HStack {
                Text("Word count: \(currentWordCount) / \(maxWordsInTerms)")
                    .font(.caption)
                    .foregroundColor(isOverWordLimit ? .red : (currentWordCount > maxWordsInTerms * 3/4 ? .orange : .gray))
                
                Spacer()
                
                if isOverWordLimit {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("Exceeds limit")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var truncatedPartyName: String {
        if party_name.count > maxPartyNameCharacters {
            return String(party_name.prefix(maxPartyNameCharacters)) + "…"
        }
        return party_name
    }
    
    private var customHeaderView: some View {
        Text(truncatedPartyName.isEmpty ? "New Party" : truncatedPartyName)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
    }
    
    private var partyNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Enter party name")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Spacer()
                
                // Character count indicator
                Text("\(party_name.count)/\(maxPartyNameCharacters)")
                    .foregroundColor(party_name.count > maxPartyNameCharacters ? .red : .gray)
                    .font(.caption)
            }
            .padding(.horizontal)
            
            HStack {
                TextField("Party Name", text: $party_name)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(party_name.count > maxPartyNameCharacters ? Color.red : Color.clear, lineWidth: 2)
                    )
                    .onChange(of: party_name) { newValue in
                        // Enforce character limit
                        if newValue.count > maxPartyNameCharacters {
                            party_name = String(newValue.prefix(maxPartyNameCharacters))
                            
                            // Provide haptic feedback when limit is reached
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                
                Button(action: randomizePartyName) {
                    Image(systemName: "die.face.5.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
            }
            .padding(.horizontal)
            
            // Warning message when approaching or exceeding limit
            if party_name.count > maxPartyNameCharacters * 4/5 { // Show warning at 80% of limit
                HStack(spacing: 6) {
                    Image(systemName: party_name.count > maxPartyNameCharacters ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .foregroundColor(party_name.count > maxPartyNameCharacters ? .red : .orange)
                        .font(.caption)
                    
                    Text(party_name.count > maxPartyNameCharacters ?
                        "Party name has been truncated to \(maxPartyNameCharacters) characters" :
                        "Approaching character limit")
                        .font(.caption)
                        .foregroundColor(party_name.count > maxPartyNameCharacters ? .red : .orange)
                }
                .padding(.horizontal)
                .transition(.opacity)
            }
        }
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading) {
            Text("Choose privacy option")
                .foregroundColor(.white)
                .font(.headline)
                .padding(.horizontal)

            Picker("Privacy", selection: $privacy) {
                Text("Open").tag("Open")
                Text("Friends Only").tag("Friends Only")
                Text("Invite Only").tag("Invite Only")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
    }
    
    private var maxMembersSection: some View {
        Stepper(value: $max_members, in: 2...50) {
            Text("Max Members: \(max_members)")
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if !errorMessage.isEmpty {
            Text(errorMessage)
                .foregroundColor(.red)
                .padding(.horizontal)
        }
    }
    
    private var submitButtonSection: some View {
        Button(action: submitBet) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(canProceed ? Color.green : Color.gray)
                    .frame(height: 50)

                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Create Bet Party")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .disabled(!canProceed || isSubmitting)
    }
    
    @ViewBuilder
    private var validationSection: some View {
        if !canProceed {
            VStack(alignment: .leading, spacing: 4) {
                Text("Please complete all required fields to create the bet party")
                    .foregroundColor(.red)
                    .font(.caption)
                
                if isOverWordLimit {
                    Text("• Terms exceed \(maxWordsInTerms) word limit (\(currentWordCount) words)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Functions
    
    func randomizePartyName() {
        if let fileURL = Bundle.main.url(forResource: "party_names", withExtension: "txt") {
            do {
                let contents = try String(contentsOf: fileURL)
                let suggestions = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
                party_name = suggestions.randomElement() ?? "My Betting Party"
            } catch {
                print("Error reading party names: \(error)")
                party_name = "My Betting Party"
            }
        } else {
            print("party_names.txt not found")
            party_name = "My Betting Party"
        }
    }


    func submitBet() {
        guard let userId = userId else {
            print("Error: userId is nil")
            errorMessage = "User ID is missing"
            return
        }
        
        guard !party_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Party name cannot be empty")
            errorMessage = "Party name cannot be empty"
            return
        }
        
        guard !privacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Error: Privacy option must be selected")
            errorMessage = "Privacy option must be selected"
            return
        }
        
        // Check word limit before submitting
        guard !isOverWordLimit else {
            errorMessage = "Terms exceed the \(maxWordsInTerms) word limit. Please reduce the text length."
            return
        }
        
        // Handle bet type validation differently
        let validOptions: [String]
        if betType == "normal" {
            // For normal bets, validate that we have valid bet options (filter out empty ones)
            validOptions = betOptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            guard validOptions.count >= 2 else {
                errorMessage = "At least 2 valid options are required for normal bets"
                return
            }
        } else {
            // For other bet types (timer, contest), use empty array as options aren't needed
            validOptions = []
        }
        
        isSubmitting = true
        errorMessage = ""

        let party_code = UUID().uuidString.prefix(6).uppercased()

        // Handle optional date formatting
        let formattedDate: String?
        if let date = selectedDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Match database format
            formattedDate = dateFormatter.string(from: date)
        } else {
            formattedDate = nil
        }
        
        
        print("🔄 Formatted date: \(formattedDate ?? "nil")") // Debug log
        
        // Calculate timer duration in seconds for timer and contest bets
        let timerDuration: Int?
        if betType == "timed" || betType == "contest" {
            print(timerDays, timerHours, timerMinutes, timerSeconds)
            timerDuration = (timerDays * 24 * 60 * 60) + (timerHours * 60 * 60) + (timerMinutes * 60) + timerSeconds
        } else {
            timerDuration = nil
        }
        
        struct Payload: Encodable {
            let created_by: String
            let party_name: String
            let privacy_option: String
            let max_members: Int
            let bet: String
            let bet_date: String?
            let bet_type: String
            let options: [String]
            let terms: String
            let status: String
            let party_code: String
            let max_selections: Int?
            let timer_duration: Int?
            let allow_early_finish: Bool?
            let contest_unit: String?
            let contest_target: Int?
            let allow_ties: Bool?
        }

        let payload = Payload(
            created_by: userId.uuidString,
            party_name: party_name,
            privacy_option: privacy,
            max_members: max_members,
            bet: betPrompt,
            bet_date: formattedDate,
            bet_type: betType, // Using bet_type instead of betType
            options: validOptions,
            terms: betTerms,
            status: "open",
            party_code: String(party_code),
            max_selections: betType == "normal" ? max_selections : nil,
            timer_duration: timerDuration,
            allow_early_finish: betType == "timed" ? true : nil, // Default for timer bets
            contest_unit: betType == "contest" ? "points" : nil, // Default for contest bets
            contest_target: betType == "contest" ? target : nil, // Default target for contest bets
            allow_ties: betType == "contest" ? false : nil // Default for contest bets
        )

        Task {
            do {
                print("🔄 Creating \(betType) party with code: \(party_code)")
                print("🔄 Timer duration: \(timerDuration ?? 0) seconds")
                print("🔄 Date: \(formattedDate ?? "no date")")
                print("🔄 Max selections: \(betType == "normal" ? max_selections : 0)")
                
                // Insert the party
                let response = try await supabaseClient
                    .from("Parties")
                    .insert(payload)
                    .select()
                    .single()
                    .execute()

                print("✅ Raw insert response: \(String(data: response.data, encoding: .utf8) ?? "No data")")

                // Decode the response to get the party ID
                let decodedParty = try JSONDecoder().decode(Party.self, from: response.data)
                print("✅ Successfully created party: \(decodedParty)")
                
                // Add the creator as a member to the Party Members table
                if let partyId = decodedParty.id {
                    print("🔄 Adding creator as member to party ID: \(partyId)")
                    
                    let memberPayload = PartyMemberInsert(
                        party_id: Int(partyId),
                        user_id: userId.uuidString
                    )
                    
                    let memberResponse = try await supabaseClient
                        .from("Party Members")
                        .insert(memberPayload)
                        .execute()
                    
                    print("✅ Successfully added creator as member")
                    print("✅ Member response: \(String(data: memberResponse.data, encoding: .utf8) ?? "No data")")
                } else {
                    print("⚠️ Warning: Could not get party ID from response")
                }
                
                // Navigate to PartyDetailsView
                await MainActor.run {
                    self.createdPartyCode = String(party_code)
                    self.showPartyDetails = true
                    self.isSubmitting = false
                    print("✅ Navigation set up for party code: \(self.createdPartyCode)")
                }

            } catch {
                print("❌ Error submitting bet: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = "Failed to create party: \(error.localizedDescription)"
                }
            }
        }
    }
}
