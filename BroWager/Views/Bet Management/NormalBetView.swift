// Updated Bet Creation Flow with Optional Date

import SwiftUI

#Preview {
    NormalBetView(
        navPath: .constant(NavigationPath()),
        email: "preview@example.com",
        userId: UUID(),
        selectedCategory: BetCategoryView.BetCategory.sports,
        betType: "normal"
    )
}

struct NormalBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let userId: UUID?
    let selectedCategory: BetCategoryView.BetCategory?
    let betType: String

    @State private var aiSuggestions: [String] = []
    @State private var betPrompt: String = ""
    @State private var selectedDate = Date()
    @State private var isDateEnabled = false // New toggle state
    @State private var isNextActive = false
    @State private var optionCount = 4
    @State private var max_selections = 1
    @State private var showDateInfo = false // New state for showing date info
    @State private var isOptimizingQuestion = false
    
    // Refresh cooldown states - using AppStorage for persistence
    @AppStorage("aiRefreshCount") private var refreshCount = 0
    @AppStorage("lastRefreshTimestamp") private var lastRefreshTimestamp: Double = 0
    @State private var isRefreshDisabled = false
    @State private var cooldownTimer: Timer?
    @State private var timeRemaining: Int = 0
    
    // Date picker states
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedDay = Calendar.current.component(.day, from: Date())
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isProcessingDate = false
    @State private var detectedDateText: String = ""
    
    
    private let months = Array(1...12)
    private let currentYear = Calendar.current.component(.year, from: Date())
    private let maxRefreshesPerMinute = 3
    
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
    
    // Validation computed property
    private var canProceed: Bool {
        !betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(category.rawValue)
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(category.description)
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    
                    // AI Suggestions Header
                    VStack(spacing: 12) {
                        HStack {
                            Text("AI Suggestions: Click to fill")
                                .foregroundColor(.white)
                                .font(.title2)
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    await handleRefreshTap()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(isRefreshDisabled ? .gray : .white)
                                    .font(.title2)
                                    .padding(8)
                                    .background((isRefreshDisabled ? Color.gray : Color.blue).opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .disabled(isRefreshDisabled)
                        }
                        .padding(.horizontal)
                        
                        // Cooldown message with live timer
                        if isRefreshDisabled && timeRemaining > 0 {
                            HStack {
                                Spacer()
                                Text("Cooldown: \(timeRemaining)s remaining")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .padding(.horizontal)
                                Spacer()
                            }
                        } else if refreshCount > 0 && !isRefreshDisabled {
                            HStack {
                                Spacer()
                                Text("\(maxRefreshesPerMinute - refreshCount) refreshes remaining this minute")
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
                                    betPrompt = suggestion
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
                            Text("Write your Bet")
                                .foregroundColor(.white)
                                .font(.title2)
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    await optimizeBetQuestion()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "wand.and.stars")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 16))
                                    Text("Optimize")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .disabled(betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.vertical)
                        
                        TextEditor(text: $betPrompt)
                            .scrollContentBackground(.hidden)
                            .frame(height: 130)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                            .onChange(of: betPrompt) { newValue in
                                Task {
                                    await detectAndProcessDate(from: newValue)
                                }
                            }
                    }
                    .padding(.horizontal)
                    
                    // Date Toggle Section with Info Button
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Set specific date for bet")
                                .foregroundColor(.white)
                                .font(.title2)
                            
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
                        }
                        .padding(.horizontal)
                        
                        // Date Picker Section (only shown when toggle is enabled)
                        if isDateEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select time of match")
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
                    .onChange(of: optionCount) { _ in
                        // Ensure max_selections doesn't exceed optionCount - 1
                        if max_selections >= optionCount {
                            max_selections = max(1, optionCount - 1)
                        }
                    }
                    
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
                    
                    NavigationLink(
                        destination: BetOptionsView(
                            navPath: $navPath,
                            betPrompt: betPrompt,
                            selectedDate: isDateEnabled ? selectedDate : nil, // Pass nil if date is disabled
                            email: email,
                            userId: userId,
                            optionCount: optionCount,
                            max_selections: max_selections,
                            selectedCategory: selectedCategory
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

                    
                    // Validation message
                    if !canProceed {
                        Text("Please enter a bet question to continue")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .onAppear {
                    loadAISuggestions()
                    checkCooldownStatus()
                }
                .onDisappear {
                    cooldownTimer?.invalidate()
                }
            }
        }
        .alert("Date Selection Info", isPresented: $showDateInfo) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("You can either manually select a date or simply type natural phrases like 'tonight', 'tomorrow night', 'Sunday morning', or 'next Friday at 7pm' in your bet question - the app will automatically detect and set the date for you!")
        }
    }
    
    private func dateFromComponents() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = selectedYear
        components.month = selectedMonth
        components.day = selectedDay
        
        if let date = calendar.date(from: components) {
            return date
        } else {
            components.day = 1
            guard let firstOfMonth = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
                return Date()
            }
            components.day = min(selectedDay, range.count)
            return calendar.date(from: components) ?? Date()
        }
    }
    
    private func updateSelectedDate() {
        let newDate = dateFromComponents()
        selectedDate = newDate
    }
    
    private func formattedSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
    
    private func getCurrentTimestamp() -> Double {
        return Date().timeIntervalSince1970
    }
    
    private func checkCooldownStatus() {
        let currentTime = getCurrentTimestamp()
        let timeSinceLastRefresh = currentTime - lastRefreshTimestamp
        
        // Reset if more than 60 seconds have passed
        if timeSinceLastRefresh >= 60 {
            refreshCount = 0
            isRefreshDisabled = false
            timeRemaining = 0
            cooldownTimer?.invalidate()
            return
        }
        
        // Check if we're in cooldown
        if refreshCount >= maxRefreshesPerMinute {
            isRefreshDisabled = true
            timeRemaining = max(0, Int(60 - timeSinceLastRefresh))
            startLiveTimer()
        } else {
            isRefreshDisabled = false
            timeRemaining = 0
        }
    }
    
    private func startLiveTimer() {
        cooldownTimer?.invalidate()
        
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let currentTime = getCurrentTimestamp()
                let timeSinceLastRefresh = currentTime - lastRefreshTimestamp
                
                if timeSinceLastRefresh >= 60 {
                    // Cooldown period has ended
                    refreshCount = 0
                    isRefreshDisabled = false
                    timeRemaining = 0
                    cooldownTimer?.invalidate()
                } else {
                    // Update remaining time
                    timeRemaining = max(0, Int(60 - timeSinceLastRefresh))
                    if timeRemaining == 0 {
                        refreshCount = 0
                        isRefreshDisabled = false
                        cooldownTimer?.invalidate()
                    }
                }
            }
        }
    }
    
    private func handleRefreshTap() async {
        let currentTime = getCurrentTimestamp()
        let timeSinceLastRefresh = currentTime - lastRefreshTimestamp
        
        // Reset counter if more than 60 seconds have passed
        if timeSinceLastRefresh >= 60 {
            refreshCount = 0
        }
        
        // Check if we've exceeded the limit
        if refreshCount >= maxRefreshesPerMinute {
            isRefreshDisabled = true
            timeRemaining = max(0, Int(60 - timeSinceLastRefresh))
            startLiveTimer()
            return
        }
        
        // Increment counter and refresh
        refreshCount += 1
        lastRefreshTimestamp = currentTime
        await refreshAISuggestions()
        
        // Start cooldown if we've hit the limit
        if refreshCount >= maxRefreshesPerMinute {
            isRefreshDisabled = true
            timeRemaining = 60
            startLiveTimer()
        }
    }
    
    @MainActor
    func detectAndProcessDate(from text: String) async {
        // Don't process if already processing or text is too short
        guard !isProcessingDate && text.count > 3 else { return }
        
        let dateKeywords = [
            "tonight", "tomorrow", "today", "sunday", "monday", "tuesday", "wednesday",
            "thursday", "friday", "saturday", "this weekend", "next week", "next weekend",
            "morning", "afternoon", "evening", "night", "pm", "am"
        ]
        
        let lowercasedText = text.lowercased()
        let containsDateKeyword = dateKeywords.contains { lowercasedText.contains($0) }
        
        guard containsDateKeyword else { return }
        
        isProcessingDate = true
        
        do {
            let parsedDate = try await parseNaturalLanguageDate(from: text)
            if let date = parsedDate {
                selectedDate = date
                isDateEnabled = true
                updateDateComponentsFromDate(date)
                detectedDateText = "Auto-detected: \(formatDetectedDate(date))"
            }
        } catch {
            print("Failed to parse natural language date: \(error)")
        }
        
        isProcessingDate = false
    }

    @MainActor
    func parseNaturalLanguageDate(from text: String) async throws -> Date? {
        let prompt = """
        Extract and parse any date/time information from this text: "\(text)"
        
        Current date and time: \(Date())
        
        Look for phrases like:
        - "tonight" (today at 8 PM)
        - "tomorrow night" (tomorrow at 8 PM)  
        - "Sunday morning" (next Sunday at 10 AM)
        - "this weekend" (next Saturday at 7 PM)
        - "next week" (next Monday at 7 PM)
        - Specific times like "7pm", "3:30 PM"
        - Day names like "Monday", "Friday"
        
        Rules:
        - If only day is mentioned (like "Sunday"), assume 7 PM
        - If "morning" is mentioned, use 10 AM
        - If "afternoon" is mentioned, use 2 PM  
        - If "evening" or "night" is mentioned, use 8 PM
        - If "tonight" is mentioned, use today at 8 PM
        - If "tomorrow" is mentioned, use tomorrow (with appropriate time)
        - Always use the next occurrence of the mentioned day
        
        Return ONLY the date in ISO format (YYYY-MM-DD HH:MM:SS) or "NONE" if no date found.
        Do not include any other text or explanation.
        """
        
        let response = try await AIServices.shared.sendPrompt(
            prompt,
            model: "gemini-2.5-flash-lite",
            temperature: 0.1,
            maxTokens: 100
        )
        
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanResponse.uppercased() == "NONE" {
            return nil
        }
        
        // Try to parse the ISO date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if let date = formatter.date(from: cleanResponse) {
            return date
        }
        
        // Fallback: try without seconds
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: cleanResponse) {
            return date
        }
        
        // Fallback: try date only (add default time)
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: cleanResponse) {
            let calendar = Calendar.current
            return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date) // 7 PM default
        }
        
        return nil
    }

    private func updateDateComponentsFromDate(_ date: Date) {
        let calendar = Calendar.current
        selectedMonth = calendar.component(.month, from: date)
        selectedDay = calendar.component(.day, from: date)
        selectedYear = calendar.component(.year, from: date)
    }

    private func formatDetectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @MainActor
    func optimizeBetQuestion() async {
        guard !betPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isOptimizingQuestion = true
        
        do {
            let categoryContext = selectedCategory?.aiPromptContext ?? "general activities"
            let categoryName = selectedCategory?.rawValue.lowercased() ?? "general"
            
            let prompt = """
            Optimize this betting question for clarity, engagement, and measurability: "\(betPrompt)"
            
            This is a \(categoryName) category bet. Please:
            1. Add specific team names, player names, or event details if applicable
            2. Make the question more specific and measurable
            3. Ensure it's clear what constitutes a win/loss
            4. Add relevant context or details that make it more engaging
            5. Keep the core intent but make it better for betting
            
            Context: \(categoryContext)
            
            Return only the optimized question, no additional text or explanation.
            """
            
            let optimizedQuestion = try await AIServices.shared.sendPrompt(
                prompt,
                model: "gemini-2.5-flash-lite",
                temperature: 0.7,
                maxTokens: 200
            )
            
            betPrompt = optimizedQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch {
            print("Failed to optimize bet question: \(error)")
        }
        
        isOptimizingQuestion = false
    }
    
    @MainActor
    func loadAISuggestions() {
        let calendar = Calendar.current
        let currentDate = selectedDate
        
        selectedMonth = calendar.component(.month, from: currentDate)
        selectedDay = calendar.component(.day, from: currentDate)
        selectedYear = calendar.component(.year, from: currentDate)
        
        Task {
            await refreshAISuggestions()
        }
    }

    @MainActor
    func refreshAISuggestions() async {
        do {
            print("Attempting to fetch category-based AI suggestions...")
            
            let result = try await AIServices.shared.generateCategoryBetSuggestions(
                category: selectedCategory,
                count: 5
            )
            print("Raw AI Response: \(result)")
            aiSuggestions = result
        } catch {
            print("AI decoding error: \(error.localizedDescription)")
            
            // Category-specific fallback suggestions
            let fallbackSuggestions = getCategoryFallbackSuggestions()
            aiSuggestions = fallbackSuggestions
        }
    }
    
    private func getCategoryFallbackSuggestions() -> [String] {
        guard let category = selectedCategory else {
            return [
                "Who will finish their coffee first this morning?",
                "What will be the next song that comes on shuffle?",
                "Which elevator will arrive first when we press the button?",
                "How many red cars will we see in the next 10 minutes?",
                "Who will get the most likes on their next social media post?"
            ]
        }
        
        switch category {
        case .sports:
            return [
                "Which team will score first in the next game?",
                "Who will run the fastest mile in our group?",
                "Which player will have the most assists this season?",
                "Will the home team win their next match?",
                "Who will make the most free throws out of 10 attempts?"
            ]
        case .food:
            return [
                "Which restaurant will we choose for dinner tonight?",
                "Who can eat the spiciest food without drinking water?",
                "What will be the most popular pizza topping ordered?",
                "Which of us will finish our meal first?",
                "Will the new restaurant get good reviews this week?"
            ]
        case .lifeEvents:
            return [
                "Who will get engaged first in our friend group?",
                "Which of us will get promoted this year?",
                "Who will move to a new city first?",
                "Which couple will celebrate their anniversary first?",
                "Who will learn a new skill by the end of the month?"
            ]
        case .politics:
            return [
                "Which candidate will win the local election?",
                "What will be the voter turnout percentage?",
                "Which political party will gain more seats?",
                "Will the new policy be approved this quarter?",
                "Which state will announce results first?"
            ]
        case .entertainment:
            return [
                "Which movie will win Best Picture at the Oscars?",
                "Who will release a surprise album next?",
                "Which TV show will get renewed for another season?",
                "Will the next big blockbuster be a hit or a flop?",
                "Which celebrity couple will make headlines this week?"
            ]
        case .other:
            return [
                "What will be the weather like tomorrow?",
                "Which movie will be #1 at the box office this weekend?",
                "Who will get the next text message first?",
                "What color car will drive by next?",
                "Which of us will wake up earliest tomorrow?"
            ]
        }
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

struct BetOptionsView: View {
    @Binding var navPath: NavigationPath
    let betPrompt: String
    let selectedDate: Date? // Now optional
    let email: String
    let userId: UUID?
    let optionCount: Int
    let max_selections: Int
    let selectedCategory: BetCategoryView.BetCategory?

    @State private var betOptions: [String] = []
    @State private var betTerms: String = ""
    @State private var isNextActive = false
    @State private var isGeneratingOptions = false
    @State private var isOptimizing = false
    
    private var filledOptionsCount: Int {
        betOptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
    
    // Validation computed property
    private var canProceed: Bool {
        betOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } &&
        !betTerms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                // Category and Date Display
                HStack {
                    if let category = selectedCategory {
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(category.color)
                            Text(category.rawValue)
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                    }
                    
                    Spacer()
                    
                    // Only show date if it's set
                    if let date = selectedDate {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("Bet Date: \(date, style: .date)")
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
                .padding(.horizontal)

                HStack {
                    Text("Options (")
                            .foregroundColor(.white)
                            .font(.headline)
                        +
                        Text("\(filledOptionsCount)")
                            .foregroundColor(filledOptionsCount == optionCount ? .green : .orange)
                            .font(.headline)
                        +
                        Text(" filled / \(optionCount) required)")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                    Spacer()
                    Button {
                        Task {
                            await generateOptions(betPrompt: betPrompt, date: selectedDate)
                        }
                    } label: {
                        if isGeneratingOptions {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .font(.system(size: 20))
                        }
                    }
                    .disabled(isGeneratingOptions)
                }
                .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(betOptions.indices, id: \.self) { index in
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
                    }
                }
                .frame(maxHeight: 250)

                HStack {
                    Text("Terms (Penalties, Prizes, Rules)")
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        generateTerms(date: selectedDate)
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal)

                TextEditor(text: $betTerms)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .scrollContentBackground(.hidden)

                Spacer()
                
                // AI Optimization Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AI Optimization")
                            .foregroundColor(.white)
                            .font(.headline)
                        
                        Spacer()
                        
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
                    
                    if isOptimizing {
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
                }
                .padding(.horizontal)
                

                NavigationLink(
                    destination: FinalizeBetView(
                        navPath: $navPath,
                        email: email,
                        betPrompt: betPrompt,
                        selectedDate: selectedDate, // Pass the optional date
                        betOptions: betOptions,
                        betTerms: betTerms,
                        bet_type: "normal",
                        max_selections: max_selections,
                        userId: userId
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
                    Text("View Summary")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canProceed ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(!canProceed)

                
                // Validation message
                if !canProceed {
                    Text("Please fill out all options and terms to continue")
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
            }
            .padding(.top)
        }
        .onAppear {
            // Initialize with the specified number of empty options
            if betOptions.isEmpty {
                betOptions = Array(repeating: "", count: optionCount)
                // Auto-generate options when the view appears
                Task {
                    await generateOptions(betPrompt: betPrompt, date: selectedDate)
                }
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
    
    func generateOptions(betPrompt: String, date: Date?) {
        isGeneratingOptions = true
        Task {
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
                Generate well-organized, user-friendly terms and conditions for a \(categoryName) bet \(dateContext) 
                involving these options: \(betDescription). 
                
                CRITICAL REQUIREMENT: Each participant can select a maximum of \(max_selections) option(s) out of \(betOptions.count) total options.
                This selection limit must be PROMINENTLY featured and clearly emphasized in the terms.
                
                Format the response with clear sections and use formatting like:
                - **Bold text** for important rules
                - CAPITAL LETTERS for critical information
                - Bullet points for easy reading
                - Clear section headers
                
                Structure the terms with these sections:
                1. **SELECTION RULES** (Make this section very prominent with the max selection limit)
                2. **BET DETAILS** (What the bet is about and timeline)
                3. **DETERMINATION OF RESULTS** (How winners are decided)
                4. **DISPUTE RESOLUTION** (What happens if there are disagreements)
                5. **CONSEQUENCES & REWARDS** (What happens to winners/losers)
                
                This bet is specifically about \(categoryContext), so include relevant rules and considerations for this type of bet.
                Use simple language suitable for users, avoid legal jargon, do not use placeholders like [Your Company], 
                and keep the response under 400 words but well-formatted.
                
                Make the selection limit rule impossible to miss by using multiple formatting techniques.
                """
                
                let responseText = try await AIServices.shared.sendPrompt(
                    prompt,
                    model: "gemini-2.5-flash-lite",
                    temperature: 0.7,
                    maxTokens: 800
                )
                
                betTerms = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                
            } catch {
                print("Failed to generate bet terms: \(error)")
                
                // Category-specific fallback terms with improved formatting
                let categorySpecificTerms = getCategoryFallbackTerms(date: date)
                betTerms = categorySpecificTerms
            }
        }
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
    func generateCategoryBetSuggestions(category: BetCategoryView.BetCategory?, count: Int) async throws -> [String] {
        let categoryContext = category?.aiPromptContext ?? "general everyday activities"
        let categoryName = category?.rawValue.lowercased() ?? "general"
        
        let prompt = """
        Generate \(count) fun and creative betting questions specifically about \(categoryContext).
        These should be engaging \(categoryName) situations that friends can make bets about.
        
        Focus exclusively on \(categoryContext) and make them:
        - Realistic and achievable
        - Fun for friends to bet on
        - Measurable with clear outcomes
        - Appropriate for social betting
        - Timeless (not dependent on specific dates or events unless explicitly time-based)
        
        Examples of \(categoryName) bets should include scenarios like \(getSamplePrompts(for: category)).
        
        Return only the betting questions, one per line, without numbering or additional text.
        Make them diverse and engaging for \(categoryName) enthusiasts.
        """
        
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

struct FinalizeBetView: View {
    @Binding var navPath: NavigationPath
    let email: String
    let betPrompt: String
    let selectedDate: Date? // Now optional
    let betOptions: [String]
    let betTerms: String
    let bet_type: String
    let max_selections: Int
    let userId: UUID?

    @State private var party_name: String = ""
    @State private var privacy: String = "Open" // Set default to "Open"
    @State private var max_members: Int = 2
    @State private var terms: String = ""
    @State private var isSubmitting = false
    @State private var showPartyDetails = false
    @State private var createdPartyCode: String = ""
    @State private var errorMessage: String = ""
    
    @Environment(\.supabaseClient) private var supabaseClient
    
    // Validation computed property - privacy is now mandatory
    private var canProceed: Bool {
        !party_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !privacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Date Display (conditional)
                    if let date = selectedDate {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("Bet Date")
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
                                Text("Bet Timing")
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
                    
                    // Bet Summary Section
                    // Enhanced Bet Summary Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Bet Summary")
                            .foregroundColor(.white)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // Party Details
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Party Details", systemImage: "person.3.fill")
                                .foregroundColor(.blue)
                                .font(.headline)
                            
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
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        
                        // Bet Question
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Bet Question", systemImage: "questionmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.headline)
                            
                            Text(betPrompt)
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        // Options Summary
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
                        
                        // Terms Summary
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
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading) {
                        Text("Enter party name")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal)
                        HStack {
                            TextField("Party Name", text: $party_name)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            Button(action: randomizePartyName) {
                                Image(systemName: "die.face.5.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            }
                        }.padding(.horizontal)
                    }

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

                    Stepper(value: $max_members, in: 2...50) {
                        Text("Max Members: \(max_members)").foregroundColor(.white)
                    }.padding(.horizontal)

                    // Show error message if any
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

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

                    // Validation message
                    if !canProceed {
                        Text("Please complete all required fields to create the bet party")
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
        }
        .navigationDestination(isPresented: $showPartyDetails) {
            PartyDetailsView(party_code: createdPartyCode, email: email)
        }
    }

    func randomizePartyName() {
        let suggestions = [
            "Bet Bros",
            "Wager Warriors",
            "Game Day Squad",
            "Prediction Party",
            "Lock & Load",
            "Sure Things",
            "Betting Brigade",
            "Odds Squad",
            "Props & Profits",
            "Smart Money",
            "The Predictors",
            "Bet Busters",
            "Wager Wizards",
            "Lucky Legends",
            "Risk Takers"
        ]

        party_name = suggestions.randomElement() ?? "My Betting Party"
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
        
        // Validate that we have valid bet options (filter out empty ones)
        let validOptions = betOptions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard validOptions.count >= 2 else {
            errorMessage = "At least 2 valid options are required"
            return
        }
        
        isSubmitting = true
        errorMessage = ""

        let party_code = UUID().uuidString.prefix(6).uppercased()

        // Handle optional date formatting - FIXED: Use nil instead of empty string
        let formattedDate: String?
        if let date = selectedDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd" // Use ISO date format for database
            formattedDate = dateFormatter.string(from: date)
        } else {
            formattedDate = nil  // FIXED: Use nil instead of empty string
        }
        
        print("🔄 Formatted date: \(formattedDate ?? "nil")") // Debug log
        
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
            let max_selections: Int
        }

        let payload = Payload(
            created_by: userId.uuidString,
            party_name: party_name,
            privacy_option: privacy,
            max_members: max_members,
            bet: betPrompt,
            bet_date: formattedDate,
            bet_type: bet_type,
            options: validOptions,
            terms: betTerms,
            status: "open",
            party_code: String(party_code),
            max_selections: max_selections
        )

        Task {
            do {
                print("🔄 Creating party with code: \(party_code) for date: \(formattedDate ?? "no date") with max selections: \(max_selections)")
                
                // First, insert the party
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
                
                // Now add the creator as a member to the Party Members table
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
