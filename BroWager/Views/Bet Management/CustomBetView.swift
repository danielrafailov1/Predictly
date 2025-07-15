import SwiftUI
import Supabase

struct CustomBetView: View {
    let email: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.supabaseClient) private var supabaseClient
    
    @State private var partyName: String = ""
    @State private var betTitle: String = ""
    @State private var selectedOutcomeType: OutcomeType = .yesNo
    @State private var customOutcome1: String = ""
    @State private var customOutcome2: String = ""
    @State private var selectedDeadlineType: DeadlineType = .date
    @State private var selectedDate = Date()
    @State private var agreementText: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    
    enum OutcomeType {
        case yesNo
        case custom
    }
    
    enum DeadlineType {
        case date
        case agreement
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    Text("Create Custom Bet")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 32)
                    
                    // Party Name Section
                    VStack(spacing: 12) {
                        Text("Party Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            TextField("Enter party name", text: $partyName)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            Button(action: generateRandomName) {
                                Image(systemName: "dice.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Bet Title Section
                    VStack(spacing: 12) {
                        Text("Bet Title")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("Enter bet title", text: $betTitle)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    
                    // Bet Outcome Section
                    VStack(spacing: 16) {
                        Text("Bet Outcome")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            Button(action: { selectedOutcomeType = .yesNo }) {
                                HStack {
                                    Text("Yes/No")
                                        .font(.system(size: 16, weight: .medium))
                                    if selectedOutcomeType == .yesNo {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedOutcomeType == .yesNo ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedOutcomeType == .yesNo ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            Button(action: { selectedOutcomeType = .custom }) {
                                HStack {
                                    Text("Custom")
                                        .font(.system(size: 16, weight: .medium))
                                    if selectedOutcomeType == .custom {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedOutcomeType == .custom ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedOutcomeType == .custom ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        
                        if selectedOutcomeType == .custom {
                            VStack(spacing: 12) {
                                TextField("First outcome", text: $customOutcome1)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                
                                TextField("Second outcome", text: $customOutcome2)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Bet Deadline Section
                    VStack(spacing: 16) {
                        Text("Bet Deadline")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            Button(action: { selectedDeadlineType = .date }) {
                                HStack {
                                    Text("Date")
                                        .font(.system(size: 16, weight: .medium))
                                    if selectedDeadlineType == .date {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedDeadlineType == .date ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedDeadlineType == .date ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            
                            Button(action: { selectedDeadlineType = .agreement }) {
                                HStack {
                                    Text("Agreement")
                                        .font(.system(size: 16, weight: .medium))
                                    if selectedDeadlineType == .agreement {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedDeadlineType == .agreement ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedDeadlineType == .agreement ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        
                        if selectedDeadlineType == .date {
                            DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .tint(.blue)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        } else {
                            TextField("Enter agreement terms", text: $agreementText)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Create Party Button
                    Button(action: {
                        // TODO: Implement party creation
                    }) {
                        HStack {
                            Text("Create Party")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: .constant(NavigationPath()), email: email)
        }
        .onAppear {
            Task {
                profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
            }
        }
    }
    
    private func generateRandomName() {
        let adjectives = ["Epic", "Legendary", "Awesome", "Super", "Mega", "Ultra", "Pro", "Elite", "Prime", "Royal"]
        let nouns = ["Party", "Squad", "Team", "Crew", "Gang", "Club", "League", "Alliance", "Union", "Federation"]
        let randomAdjective = adjectives.randomElement() ?? "Epic"
        let randomNoun = nouns.randomElement() ?? "Party"
        let randomNumber = Int.random(in: 1...999)
        partyName = "\(randomAdjective) \(randomNoun)\(randomNumber)"
    }
}

#Preview {
    NavigationView {
        CustomBetView(email: "test@example.com")
    }
} 