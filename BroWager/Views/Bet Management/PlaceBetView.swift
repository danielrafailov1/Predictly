import SwiftUI
import Supabase

struct PlaceBetView: View {
    let partyId: Int64
    let userId: String
    let partyName: String
    let betPrompt: String
    let betOptions: [String]
    let betTerms: String
    
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOption: String? = nil
    @State private var agreedToTerms: Bool = false
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showTermsSheet = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Place Your Bet")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(partyName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Bet Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24)
                            Text("What You're Betting On")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        Text(betPrompt)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.leading, 32)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // Bet Options
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "list.bullet.circle.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24)
                            Text("Choose Your Option")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        ForEach(betOptions, id: \.self) { option in
                            Button(action: {
                                selectedOption = option
                            }) {
                                HStack {
                                    Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedOption == option ? .green : .white.opacity(0.5))
                                        .font(.system(size: 20))
                                    
                                    Text(option)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .background(
                                    selectedOption == option ?
                                    Color.green.opacity(0.2) : Color.white.opacity(0.1)
                                )
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedOption == option ? Color.green : Color.white.opacity(0.2),
                                            lineWidth: selectedOption == option ? 2 : 1
                                        )
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Terms and Conditions
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 24)
                            Text("Terms & Conditions")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button("View Full Terms") {
                                showTermsSheet = true
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        }
                        
                        Text(betTerms.prefix(150) + (betTerms.count > 150 ? "..." : ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.leading, 32)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                agreedToTerms.toggle()
                            }) {
                                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                    .foregroundColor(agreedToTerms ? .green : .white.opacity(0.5))
                                    .font(.system(size: 22))
                            }
                            
                            Text("I agree to the terms and conditions")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.leading, 32)
                        .padding(.top, 8)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // Submit Button
                    Button(action: submitBet) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Submitting...")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Submit Bet")
                            }
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            (selectedOption != nil && agreedToTerms && !isSubmitting) ?
                            Color.green : Color.gray.opacity(0.5)
                        )
                        .cornerRadius(12)
                    }
                    .disabled(selectedOption == nil || !agreedToTerms || isSubmitting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Place Bet")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTermsSheet) {
            TermsSheet(terms: betTerms)
        }
        .alert("Bet Placed Successfully!", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your bet has been recorded. Good luck!")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func submitBet() {
        guard let selectedOption = selectedOption else { return }
        
        isSubmitting = true
        
        Task {
            do {
                // Debug: Print the values we're trying to insert
                print("DEBUG: Submitting bet with userId: \(userId), partyId: \(partyId)")
                
                // Create the bet payload - ensure proper data types
                let betPayload: [String: AnyEncodable] = [
                    "user_id": AnyEncodable(userId), // Keep as string if that's how it's stored
                    "party_id": AnyEncodable(partyId),
                    "selected_option": AnyEncodable(selectedOption),
                    "status": AnyEncodable("pending")
                ]
                
                print("DEBUG: Bet payload: \(betPayload)")
                
                // Insert into partybets table
                let response = try await supabaseClient
                    .from("partybets")
                    .insert(betPayload)
                    .execute()
                
                print("Bet submitted successfully: \(response)")
                
                await MainActor.run {
                    self.isSubmitting = false
                    self.showSuccessAlert = true
                }
                
            } catch {
                print("Error submitting bet: \(error)")
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = "Failed to submit bet: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }
}

struct TermsSheet: View {
    let terms: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(terms)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding()
                }
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper for encoding different types
struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void
    
    init<T: Encodable>(_ value: T) {
        encode = value.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

#Preview {
    PlaceBetView(
        partyId: 1,
        userId: "123",
        partyName: "Test Party",
        betPrompt: "Which team will win the game?",
        betOptions: ["Team A", "Team B", "Tie"],
        betTerms: "These are the terms and conditions for this bet. By participating, you agree to abide by all rules and regulations."
    )
}
