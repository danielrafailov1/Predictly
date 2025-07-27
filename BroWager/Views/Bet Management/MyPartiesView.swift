//
//  MyPartiesView.swift
//  BroWager
//
//  Created by Daniel Rafailov on 2025-05-16.
//

import Foundation
import SwiftUI
import Supabase

struct PartyNavigation: Hashable {
    let partyCode: String
    let email: String
}

struct MyPartiesView: View {
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var parties: [Party] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPartyDetails: (partyCode: String, email: String)? = nil
    @State private var isShowingDetails = false
    @State private var showJoinParty = false
    @State private var showPartyInvites = false
    @State private var userId: String = ""
    @State private var showProfile = false
    @State private var memberCounts: [Int64: Int] = [:]
    @State private var profileImage: Image? = nil
    @EnvironmentObject var sessionManager: SessionManager
    
    let email: String  // Add this to receive the email
    
    // Local archive/delete state
    @State private var archivedParties: [Party] = []
    @State private var deletedParties: [Party] = []
    
    // Filter options: just active, archived, deleted (removed expired filter as no expiration logic)
    @State private var partyFilter: PartyFilter = .active
    
    enum PartyFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case archived = "Archived"
        case deleted = "Deleted"
        
        var id: String { rawValue }
    }
    
    var filteredParties: [Party] {
        switch partyFilter {
        case .active:
            return parties.filter { party in
                !archivedParties.contains(where: { $0.id == party.id }) &&
                !deletedParties.contains(where: { $0.id == party.id })
            }
        case .archived:
            return archivedParties
        case .deleted:
            return deletedParties
        }
    }
    
    private var partyRows: [(party: Party, memberCount: Int, betType: String)] {
        let currentMemberCounts = memberCounts
        return filteredParties.compactMap { party in
            guard let id = party.id else { return nil } // skip parties without id
            return (
                party: party,
                memberCount: currentMemberCounts[id] ?? 1,
                betType: party.bet_type ?? ""
            )
        }
    }
    
    private var partyListSection: some View {
        if isLoading {
            AnyView(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        } else if let error = errorMessage {
            AnyView(
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        } else if filteredParties.isEmpty {
            AnyView(
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No \(partyFilter.rawValue.lowercased()) parties")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(partyFilter == .active ? "Create a new party to get started" : "")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        } else {
            AnyView(
                List {
                    ForEach(partyRows, id: \.party.id) { row in
                        NavigationLink(value: PartyNavigation(partyCode: row.party.party_code, email: email)) {
                            PartyCard(
                                party: row.party,
                                memberCount: row.memberCount,
                                betType: row.betType
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if partyFilter == .active {
                                Button(role: .destructive) {
                                    deletedParties.append(row.party)
                                    parties.removeAll { $0.id == row.party.id }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    archivedParties.append(row.party)
                                    parties.removeAll { $0.id == row.party.id }
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                            } else if partyFilter == .archived {
                                Button(role: .destructive) {
                                    deletedParties.append(row.party)
                                    archivedParties.removeAll { $0.id == row.party.id }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .padding(.horizontal, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
        }
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
            
            VStack(spacing: 0) {
                // Fixed Header
                VStack(spacing: 8) {
                    Text("My Parties")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("View and manage your active parties")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 16)
                
                Spacer().frame(height: 18)
                
                // Filter control
                Picker("Party Filter", selection: $partyFilter) {
                    ForEach(PartyFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 14)
                
                // Party Invites Button
                Button(action: { showPartyInvites = true }) {
                    HStack {
                        Image(systemName: "envelope.open.fill")
                        Text("Party Invites")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                
                // Scrollable party list area
                partyListSection
            }
        }
        .navigationDestination(for: PartyNavigation.self) { details in
            PartyDetailsView(partyCode: details.partyCode, email: details.email)
        }
        .sheet(isPresented: $showJoinParty, onDismiss: {
            Task { await loadParties() }
        }) {
            JoinPartyView(email: email)
                .environment(\.supabaseClient, supabaseClient)
        }
        .sheet(isPresented: $showPartyInvites, onDismiss: {
            Task { await loadParties() }
        }) {
            if !userId.isEmpty {
                PartyInvitesView(userId: userId)
                    .environment(\.supabaseClient, supabaseClient)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: .constant(NavigationPath()), email: email)
        }
        .onAppear {
            Task {
                do {
                    let userResponse = try await supabaseClient
                        .from("Login Information")
                        .select("user_id")
                        .eq("email", value: email)
                        .limit(1)
                        .execute()
                    struct UserIdRow: Decodable { let user_id: String }
                    let userIdRows = try JSONDecoder().decode([UserIdRow].self, from: userResponse.data)
                    if let first = userIdRows.first {
                        userId = first.user_id
                    } else {
                        print("[MyPartiesView] Failed to fetch userId: User not found")
                    }
                } catch {
                    print("[MyPartiesView] Failed to fetch userId: \(error)")
                }
                await loadParties()
                if let userEmail = sessionManager.userEmail {
                    profileImage = await fetchProfileImage(for: userEmail, supabaseClient: supabaseClient)
                }
            }
        }
    }
    
    private func loadParties() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔍 Starting to load parties for email:", email)
            
            // Get user_id from Login Information table
            let userResponse = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .execute()
            
            struct UserIDResponse: Codable {
                let user_id: String
            }
            
            let decoder = JSONDecoder()
            let userData = try decoder.decode([UserIDResponse].self, from: userResponse.data)
            
            guard let userId = userData.first?.user_id else {
                errorMessage = "User not found"
                isLoading = false
                return
            }
            
            self.userId = userId
            
            // Get parties where user is the creator
            let createdPartiesResponse = try await supabaseClient
                .from("Parties")
                .select()
                .eq("created_by", value: userId)
                .execute()
            let createdParties = try decoder.decode([Party].self, from: createdPartiesResponse.data)
            
            // Get party IDs where user is a member
            let memberPartiesResponse = try await supabaseClient
                .from("Party Members")
                .select("party_id")
                .eq("user_id", value: userId)
                .execute()
            
            struct MemberPartyResponse: Codable {
                let party_id: Int
            }
            
            let memberPartyData = try decoder.decode([MemberPartyResponse].self, from: memberPartiesResponse.data)
            let memberPartyIds = memberPartyData.map { $0.party_id }
            
            var memberParties: [Party] = []
            if !memberPartyIds.isEmpty {
                let memberPartiesResponse = try await supabaseClient
                    .from("Parties")
                    .select()
                    .in("id", values: memberPartyIds)
                    .execute()
                memberParties = try decoder.decode([Party].self, from: memberPartiesResponse.data)
            }
            
            // Combine created and member parties, removing duplicates
            var allParties = createdParties
            for memberParty in memberParties {
                if !allParties.contains(where: { $0.id == memberParty.id }) {
                    allParties.append(memberParty)
                }
            }
            
            // Fetch member counts for all parties
            let partyIds = allParties.compactMap { party -> Int? in
                guard let id = party.id else { return nil }
                return Int(id)
            }
            
            var memberCounts: [Int64: Int] = [:]
            if !partyIds.isEmpty {
                let membersResponse = try await supabaseClient
                    .from("Party Members")
                    .select("party_id")
                    .in("party_id", values: partyIds)
                    .execute()
                struct MemberRow: Codable { let party_id: Int64 }
                let memberRows = try decoder.decode([MemberRow].self, from: membersResponse.data)
                memberCounts = Dictionary(grouping: memberRows, by: { $0.party_id }).mapValues { $0.count }
            }
            
            await MainActor.run {
                self.parties = allParties
                self.isLoading = false
                self.memberCounts = memberCounts
            }
            
        } catch {
            print("❌ Error loading parties:", error)
            await MainActor.run {
                self.errorMessage = "Error loading parties: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchCreatorDetails(for party: Party) async -> String? {
        do {
            let response = try await supabaseClient
                .from("Login Information")
                .select("email")
                .eq("user_id", value: party.created_by)
                .limit(1)
                .execute()
            let decoder = JSONDecoder()
            struct CreatorInfo: Codable { let email: String }
            let info = try decoder.decode([CreatorInfo].self, from: response.data)
            return info.first?.email
        } catch {
            print("❌ Error fetching creator details: \(error)")
            return nil
        }
    }
}

struct PartyCard: View {
    let party: Party
    let memberCount: Int
    let betType: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.party_name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Members: \(memberCount)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Text(betType)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    MyPartiesView(email: "example@example.com")
        .environment(\.supabaseClient, .development)
}
