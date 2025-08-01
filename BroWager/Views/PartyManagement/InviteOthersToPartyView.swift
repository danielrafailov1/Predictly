import SwiftUI
import Supabase
import Foundation // For Codable
// Import shared model

struct InviteOthersToPartyView: View {
    let partyId: Int64
    let inviterUserId: String
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var invitedEmails: [String] = [] // Track invited emails
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Invite Others to Party")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                // Email input section
                VStack(spacing: 16) {
                    TextField("Enter email address", text: $email)
                        .font(.system(size: 18))
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("Add Email") {
                        addEmail()
                    }
                    .disabled(email.isEmpty || isLoading)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(email.isEmpty ? Color.gray.opacity(0.5) : Color.blue.opacity(0.8))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Invited emails list
                if !invitedEmails.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Emails to Invite:")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(invitedEmails, id: \.self) { emailAddress in
                                    HStack {
                                        Text(emailAddress)
                                            .foregroundColor(.white.opacity(0.9))
                                            .fontWeight(.medium)
                                        Spacer()
                                        Button(action: {
                                            removeEmail(emailAddress)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.horizontal)
                }
                
                // Status messages
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let success = successMessage {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Send invites button
                if !invitedEmails.isEmpty {
                    Button("Send Invites") {
                        Task { await sendInvites() }
                    }
                    .disabled(isLoading)
                    .foregroundColor(.white)
                    .font(.system(size: 18, weight: .semibold))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isLoading ? Color.gray.opacity(0.5) : Color.green.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
                
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func addEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic email validation
        guard isValidEmail(trimmedEmail) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        // Check if email is already in the list
        guard !invitedEmails.contains(trimmedEmail) else {
            errorMessage = "This email is already in the list"
            return
        }
        
        invitedEmails.append(trimmedEmail)
        email = ""
        errorMessage = nil
    }
    
    private func removeEmail(_ emailToRemove: String) {
        invitedEmails.removeAll { $0 == emailToRemove }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    private func sendInvites() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        var successCount = 0
        var failureCount = 0
        var failedEmails: [String] = []
        
        for emailAddress in invitedEmails {
            do {
                // Look up user_id by email
                let userResp = try await supabaseClient
                    .from("Login Information")
                    .select("user_id")
                    .eq("email", value: emailAddress)
                    .limit(1)
                    .execute()
                
                struct UserIdRow: Decodable { let user_id: String }
                let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResp.data)
                
                guard let userIdRow = userIdRows.first else {
                    failureCount += 1
                    failedEmails.append(emailAddress)
                    continue
                }
                
                let inviteeUserId = userIdRow.user_id

                // Check 1: Prevent self-invites
                if inviteeUserId == inviterUserId {
                    failureCount += 1
                    failedEmails.append(emailAddress)
                    continue
                }

                // Check 2: Prevent inviting existing members
                let membersResp = try await supabaseClient
                    .from("Party Members")
                    .select("user_id", count: .exact)
                    .eq("party_id", value: Int(partyId))
                    .eq("user_id", value: inviteeUserId)
                    .execute()
                
                if (membersResp.count ?? 0) > 0 {
                    failureCount += 1
                    failedEmails.append(emailAddress)
                    continue
                }

                // Insert invite if all checks pass
                let invite = PartyInvite(
                    party_id: partyId,
                    inviter_user_id: inviterUserId,
                    invitee_user_id: inviteeUserId,
                    status: "pending"
                )
                
                _ = try await supabaseClient
                    .from("Party Invites")
                    .insert(invite)
                    .execute()
                
                successCount += 1
                
            } catch {
                failureCount += 1
                failedEmails.append(emailAddress)
            }
        }
        
        await MainActor.run {
            self.isLoading = false
            
            if successCount > 0 && failureCount == 0 {
                self.successMessage = "All invites sent successfully!"
                self.invitedEmails = []
            } else if successCount > 0 && failureCount > 0 {
                self.successMessage = "\(successCount) invites sent successfully"
                self.errorMessage = "Failed to send \(failureCount) invites. Some users may not exist or are already in the party."
                // Remove successfully sent emails from the list
                self.invitedEmails = failedEmails
            } else {
                self.errorMessage = "Failed to send invites. Please check that the email addresses are valid and the users exist."
            }
        }
        
        // Clear messages after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            errorMessage = nil
            successMessage = nil
        }
    }
}
