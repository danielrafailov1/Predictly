//
//  JoinPartyView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-06-06.
//

import Foundation
import SwiftUI
import Supabase

struct JoinPartyView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    @Environment(\.dismiss) private var dismiss
    
    let email: String
    
    @State private var partyCode: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
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
            
            VStack(spacing: 24) {
                // Header
                Text("Join a Party")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                // Party Code Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Party Code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    TextField("Enter 6-digit code", text: $partyCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // Join Button
                Button(action: {
                    Task {
                        await joinParty()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Join Party")
                                .font(.system(size: 18, weight: .semibold))
                        }
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
                .disabled(isLoading || partyCode.isEmpty)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("You have successfully joined the party!")
        }
    }
    
    private func joinParty() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // First, get the user_id from Login Information
            let userResponse = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .execute()
            
            print("DEBUG: Raw user response data: \(String(data: userResponse.data, encoding: .utf8) ?? "No data")")
            
            if userResponse.data.isEmpty {
                errorMessage = "User not found"
                isLoading = false
                return
            }
            
            let decoder = JSONDecoder()
            struct UserLookup: Decodable {
                let user_id: String
            }
            var userId: String = ""
            do {
                let userData = try decoder.decode([UserLookup].self, from: userResponse.data)
                print("DEBUG: Decoded userData: \(userData)")
                guard let foundUserId = userData.first?.user_id else {
                    errorMessage = "User not found"
                    isLoading = false
                    return
                }
                userId = foundUserId
            } catch {
                print("DEBUG: Error decoding user: \(error)")
                errorMessage = "Error decoding user: \(error.localizedDescription)"
                isLoading = false
                return
            }
            
            print("DEBUG: Attempting to join party with code: \(partyCode)")
            let partyResponse = try await supabaseClient
                .from("Parties")
                .select("id, created_by, privacy_option")
                .eq("party_code", value: partyCode)
                .limit(1)
                .execute()
            
            print("DEBUG: Raw party response data: \(String(data: partyResponse.data, encoding: .utf8) ?? "No data")")
            
            struct PartyLookup: Decodable {
                let id: Int64
                let created_by: String
                let privacy_option: String
            }
            
            let parties = try decoder.decode([PartyLookup].self, from: partyResponse.data)
            guard let party = parties.first else {
                errorMessage = "Party not found"
                isLoading = false
                return
            }
            
            // --- PRIVACY CHECKS ---
            switch party.privacy_option {
            case "Invite Only":
                errorMessage = "This party is invite-only and cannot be joined with a code."
                isLoading = false
                return
                
            case "Friends Only":
                let friendsResponse = try await supabaseClient
                    .from("Friends")
                    .select("id", count: .exact)
                    .or("and(user_id.eq.\(userId),friend_id.eq.\(party.created_by)),and(user_id.eq.\(party.created_by),friend_id.eq.\(userId))")
                    .eq("status", value: "accepted")
                    .execute()
                
                if (friendsResponse.count ?? 0) == 0 {
                    errorMessage = "This is a friends-only party. You must be friends with the host to join."
                    isLoading = false
                    return
                }
                
            default: // "Open" or any other value
                break // No restrictions
            }
            
            // Check if user is already a member
            let memberCheckResponse = try await supabaseClient
                .from("Party Members")
                .select("id")
                .eq("party_id", value: Int(party.id))
                .eq("user_id", value: userId)
                .execute()
            print("DEBUG: Raw member check response: \(String(data: memberCheckResponse.data, encoding: .utf8) ?? "No data")")
            
            struct TempMemberRow: Decodable { let id: Int }
            let memberData = try? decoder.decode([TempMemberRow].self, from: memberCheckResponse.data)

            if memberData?.isEmpty == false {
                errorMessage = "You are already a member of this party"
                isLoading = false
                return
            }
            
            // Check if user is trying to join their own party
            if party.created_by == userId {
                print("DEBUG: User is trying to join their own party")
                await MainActor.run {
                errorMessage = "You cannot join your own party"
                isLoading = false
                }
                return
            }
            
            // Create new party member using the NewPartyMember struct
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let newMember = NewPartyMember(
                party_id: party.id,
                user_id: userId,
                joined_at: timestamp,
                created_at: timestamp
            )
            
            // Insert into Party Members table
            let insertResponse = try await supabaseClient
                .from("Party Members")
                .insert(newMember)
                .execute()
            print("DEBUG: Insert member response: \(String(data: insertResponse.data, encoding: .utf8) ?? "No data")")
            
            // After joining, delete any pending invites for this user to this party
            print("DEBUG: Deleting pending invite for user \(userId) to party \(party.id), if it exists.")
            _ = try await supabaseClient
                .from("Party Invites")
                .delete()
                .eq("invitee_user_id", value: userId)
                .eq("party_id", value: Int(party.id))
                .eq("status", value: "pending")
                .execute()
            
            isLoading = false
            showSuccess = true
            
        } catch {
            isLoading = false
            errorMessage = "Error joining party: \(error.localizedDescription)"
        }
    }
}

#Preview {
    JoinPartyView(email: "test@example.com")
        .environment(\.supabaseClient, .development)
}
