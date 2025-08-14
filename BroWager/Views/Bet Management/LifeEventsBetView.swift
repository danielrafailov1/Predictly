import SwiftUI

struct LifeEventsBetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBet: String? = nil
    @State private var customBet: String = ""
    let predefinedBets = [
        "Who will get a new job first?",
        "Who will move to a new city next?",
        "Who will get engaged or married next?",
        "Who will travel to a new country first?",
        "Who will buy a new car this year?",
        "Who will adopt a pet next?",
        "Who will run a marathon first?",
        "Who will start a new hobby this year?"
    ]
    var onConfirm: ((String) -> Void)? = nil
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Choose a Life Event Challenge")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 16)
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
                                .background(RoundedRectangle(cornerRadius: 12).fill(selectedBet == bet ? Color.blue.opacity(0.18) : Color.white.opacity(0.07)))
                            }
                        }
                        Divider().background(Color.white.opacity(0.2))
                        HStack {
                            TextField("Add your own life event bet...", text: $customBet)
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
                Button(action: {
                    if let bet = selectedBet {
                        onConfirm?(bet)
                        dismiss()
                    }
                }) {
                    Text("Confirm")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(selectedBet != nil ? Color.green : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(selectedBet == nil)
                .padding(.horizontal)
                Spacer()
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
        }
    }
} 
