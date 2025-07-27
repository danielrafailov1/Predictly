//
//  TimedBetView.swift
//  BroWager
//
//  Created by Nachuan Wang on 2025-07-26.
//

import SwiftUI

enum TimerState {
    case idle
    case active
    case paused
    case completed
    case cancelled
}

struct TimedBetView: View {
    // MARK: - Properties
    let betDescription: String
    let initialDays: Int
    let initialHours: Int
    let initialMinutes: Int
    let initialSeconds: Int
    
    // MARK: - State
    @State private var counter = 0
    @State private var totalDuration = 0
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var days = 0
    @State private var progress: Float = 0.0
    @State private var timerState: TimerState = .idle
    @State private var timer: Timer?
    @State private var showingTimePicker = false
    
    // MARK: - Initializer
    init(betDescription: String = "", initialDays: Int = 0, initialHours: Int = 0, initialMinutes: Int = 5, initialSeconds: Int = 0) {
        self.betDescription = betDescription
        self.initialDays = initialDays
        self.initialHours = initialHours
        self.initialMinutes = initialMinutes
        self.initialSeconds = initialSeconds
        self.totalDuration = initialDays * 86400 + initialHours * 3600 + initialMinutes * 60 + initialSeconds
    }
    
    // MARK: - Computed Properties
    private var timeRemaining: String {
        let totalSeconds = counter
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    private var progressValue: Float {
        guard totalDuration > 0 else { return 0.0 }
        return 1.0 - Float(counter) / Float(totalDuration)
    }

    // MARK: - Body
    var body: some View {
        
        NavigationView {
            ZStack() {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Timed Bet")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color.white)
                        
                        if !betDescription.isEmpty {
                            Text(betDescription)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Time Display and Progress
                    VStack(spacing: 16) {
                        ZStack {
                            CircularProgressView(progress: .constant(progressValue))
                                .frame(width: 200, height: 200)
                            
                            VStack {
                                Text(timeRemaining)
                                    .font(.system(size: 32))
                                    .fontWeight(.medium)
                                    .foregroundColor(Color.white)
                                
                                if timerState != .idle {
                                    Text(stateDescription)
                                        .font(.caption)
                                        .foregroundColor(Color.white)
                                        .foregroundColor(Color.white)
                                }
                            }
                        }
                    }
                    
                    
                    // Control Buttons
                    HStack(spacing: 20) {
                        switch timerState {
                        case .idle:
                            Button("Start") {
                                startTimer()
                            }
                            .buttonStyle(StartButtonStyle())
                            .disabled(totalTimeInSeconds == 0)
                            
                        case .active:
                            Button("Pause") {
                                pauseTimer()
                            }
                            .buttonStyle(PauseButtonStyle())
                            
                            Button("Cancel") {
                                cancelTimer()
                            }
                            .buttonStyle(CancelButtonStyle())
                            
                        case .paused:
                            Button("Resume") {
                                resumeTimer()
                            }
                            .buttonStyle(StartButtonStyle())
                            
                            Button("Cancel") {
                                cancelTimer()
                            }
                            .buttonStyle(CancelButtonStyle())
                            
                        case .completed, .cancelled:
                            Button("Reset") {
                                resetTimer()
                            }
                            .buttonStyle(StartButtonStyle())
                        }
                    }
                    
                    
                    Spacer()
                    
                }
                
                
                .padding()
                .onAppear {
                    // Set initial values from the settings
                    days = initialDays
                    hours = initialHours
                    minutes = initialMinutes
                    seconds = initialSeconds
                    
                    counter = totalTimeInSeconds
                    totalDuration = counter
                }
                
                
                
            }
            
            .alert("Timer Completed!", isPresented: .constant(timerState == .completed)) {
                Button("OK") {
                    resetTimer()
                }
            } message: {
                Text("Your timed bet has finished!")
            }
        }
    }
    
    // MARK: - Computed Properties
    private var totalTimeInSeconds: Int {
        return days * hours * 3600 + minutes * 60 + seconds
    }
    
    private var stateDescription: String {
        switch timerState {
        case .idle: return "Ready to start"
        case .active: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    // MARK: - Timer Functions
    private func startTimer() {
        totalDuration = totalTimeInSeconds
        counter = totalDuration
        timerState = .active
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if counter > 0 {
                counter -= 1
            } else {
                completeTimer()
            }
        }
    }
    
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .paused
    }
    
    private func resumeTimer() {
        timerState = .active
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if counter > 0 {
                counter -= 1
            } else {
                completeTimer()
            }
        }
    }
    
    private func cancelTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .cancelled
    }
    
    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        timerState = .completed
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = nil
        counter = 0
        totalDuration = 0
        timerState = .idle
    }
}

// MARK: - Time Picker Component
struct TimePickerComponent: View {
    @Binding var value: Int
    let label: String
    let range: ClosedRange<Int>
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker(label, selection: $value) {
                ForEach(range, id: \.self) { number in
                    Text("\(number)")
                        .tag(number)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 100)
        }
    }
}

// MARK: - Button Styles
struct StartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 70, height: 70)
            .foregroundColor(.white)
            .background(Color.green)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PauseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 70, height: 70)
            .foregroundColor(.white)
            .background(Color.orange)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 70, height: 70)
            .foregroundColor(.white)
            .background(Color.red)
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Circular Progress View
struct CircularProgressView: View {
    @Binding var progress: Float

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 12)
                .opacity(0.2)
                .foregroundColor(.gray)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(270))
                .animation(.linear(duration: 1.0), value: progress)
        }
    }
}

// MARK: - Preview
struct TimedBetView_Previews: PreviewProvider {
    static var previews: some View {
        TimedBetView()
            .previewLayout(.sizeThatFits)
    }
}
