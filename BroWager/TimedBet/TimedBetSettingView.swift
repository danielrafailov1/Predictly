import SwiftUI

struct TimedBetSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBet: String? = nil
    @State private var customBet: String = ""
    @State private var hours = 0
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var days = 0
    @State private var predefinedBets: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var onConfirm: ((String) -> Void)? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Choose a Timed Bet")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                if isLoading {
                    ProgressView("Loading suggestions...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(predefinedBets, id: \.self) { bet in
                                Button(action: { selectedBet = bet }) {
                                    HStack {
                                        Text(bet)
                                            .foregroundColor(.white)
                                            .padding(.vertical, 10)
                                        Spacer()
                                        if selectedBet == bet {
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedBet == bet ? Color.blue.opacity(0.18) : Color.white.opacity(0.07)))
                                }
                            }
                            Divider().background(Color.white.opacity(0.2))
                            HStack {
                                TextField("Add your own food bet...", text: $customBet)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(.vertical, 8)
                                Button("Add") {
                                    if !customBet.trimmingCharacters(in: .whitespaces).isEmpty {
                                        selectedBet = customBet
                                        customBet = ""
                                    }
                                }
                                .disabled(customBet.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                HStack {
                    TimerSetView(title: "days", range: 0...7, binding: $days)
                    TimerSetView(title: "hours", range: 0...23, binding: $hours)
                    TimerSetView(title: "min", range: 0...59, binding: $minutes)
                    TimerSetView(title: "sec", range: 0...59, binding: $seconds)
                }
                .frame(height: 100)
                
                confirmButton()

                Spacer()
                
                NavigationLink(destination: TimedBetView()) {
                    Text("Skip")
                        .foregroundColor(.white)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .task {
                do {
                    isLoading = true
                    errorMessage = nil
                    predefinedBets = try await AIServices.shared.generateBetSuggestions(betType: "that requires a timer count down", count: 5)
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }
    private func confirmButton() -> some View {
        NavigationLink(
            destination: {
                if let bet = selectedBet {
                    TimedBetView(
                        betDescription: bet,
                        initialDays: days,
                        initialHours: hours,
                        initialMinutes: minutes,
                        initialSeconds: seconds
                    )
                }
            },
            label: {
                Text("Confirm")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selectedBet != nil ? Color.green : Color.gray)
                    .cornerRadius(14)
            }
        )
        .disabled(selectedBet == nil)
        .padding(.horizontal)
    }
}



