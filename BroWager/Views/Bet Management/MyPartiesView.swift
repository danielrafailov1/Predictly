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
    @State private var partyStatuses: [Int64: Bool] = [:]
    let email: String  // Add this to receive the email
    // Local archive/delete state
    @State private var archivedParties: [Party] = []
    @State private var deletedParties: [Party] = []
    @State private var partyFilter: PartyFilter = .active
    
    enum PartyFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case expired = "Expired"
        case archived = "Archived"
        case deleted = "Deleted"
        var id: String { rawValue }
    }
    
    var filteredParties: [Party] {
        switch partyFilter {
        case .active:
            return parties.filter { party in
                let isExpired = partyStatuses[party.id] ?? false
                return !isExpired &&
                    !archivedParties.contains(where: { $0.id == party.id }) &&
                    !deletedParties.contains(where: { $0.id == party.id })
            }
        case .expired:
            return parties.filter { party in
                let isExpired = partyStatuses[party.id] ?? false
                return isExpired &&
                    !archivedParties.contains(where: { $0.id == party.id }) &&
                    !deletedParties.contains(where: { $0.id == party.id })
            }
        case .archived:
            return archivedParties
        case .deleted:
            return deletedParties
        }
    }
    
    private var partyRows: [(party: Party, memberCount: Int, betType: String, isExpired: Bool)] {
        let currentMemberCounts = memberCounts
        return filteredParties.map { party in
            (
                party: party,
                memberCount: currentMemberCounts[party.id] ?? 1,
                betType: party.bet_type ?? "",
                isExpired: partyStatuses[party.id] ?? false
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
                                isOngoing: !row.isExpired,
                                isExpired: row.isExpired,
                                sport: "",
                                betType: row.betType
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if partyFilter == .active || partyFilter == .expired {
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
                // Add spacing after header
                Spacer().frame(height: 18)
                // Filter control
                Picker("Party Filter", selection: $partyFilter) {
                    ForEach(PartyFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 24)
                // Add spacing after filter
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
                // Scrollable/refreshable party list area
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
                // Fetch userId on appear
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
            print("🔍 Starting to load parties...")
            print("🔍 User email:", email)
            
            // First, get the user_id from Login Information
            print("🔍 Fetching user ID from Login Information...")
            let userResponse = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .execute()
            
            print("🔍 User Response Data:", String(data: userResponse.data, encoding: .utf8) ?? "No data")
            
            // Create a simple struct to decode just the user_id
            struct UserIDResponse: Codable {
                let user_id: String
            }
            
            let decoder = JSONDecoder()
            let userData = try decoder.decode([UserIDResponse].self, from: userResponse.data)
            
            guard let userId = userData.first?.user_id else {
                print("❌ Error: User not found in database")
                errorMessage = "User not found"
                isLoading = false
                return
            }
            
            print("🔍 Found User ID:", userId)
            
            // Get parties where user is the creator
            print("🔍 Fetching parties created by user...")
            let createdPartiesResponse = try await supabaseClient
                .from("Parties")
                .select()
                .eq("created_by", value: userId)
                .execute()
            
            print("🔍 Created Parties Response:", String(data: createdPartiesResponse.data, encoding: .utf8) ?? "No data")
            
            // Get party IDs where user is a member
            print("🔍 Fetching party IDs where user is a member...")
            let memberPartiesResponse = try await supabaseClient
                .from("Party Members")
                .select("party_id")
                .eq("user_id", value: userId)
                .execute()
            
            print("🔍 Member Parties Response:", String(data: memberPartiesResponse.data, encoding: .utf8) ?? "No data")
            
            // Decode member party IDs
            struct MemberPartyResponse: Codable {
                let party_id: Int
            }
            
            let memberPartyData = try decoder.decode([MemberPartyResponse].self, from: memberPartiesResponse.data)
            let memberPartyIds = memberPartyData.map { $0.party_id }
            
            print("🔍 Member Party IDs:", memberPartyIds)
            
            // Get full party details for member parties
            var memberParties: [Party] = []
            if !memberPartyIds.isEmpty {
                print("🔍 Fetching full details for member parties...")
                let memberPartiesResponse = try await supabaseClient
                    .from("Parties")
                    .select()
                    .in("id", values: memberPartyIds)
                    .execute()
                
                print("🔍 Member Parties Full Response:", String(data: memberPartiesResponse.data, encoding: .utf8) ?? "No data")
                memberParties = try decoder.decode([Party].self, from: memberPartiesResponse.data)
            }
            
            // Decode created parties
            let createdParties = try decoder.decode([Party].self, from: createdPartiesResponse.data)
            
            // Combine and remove duplicates
            var allParties = createdParties
            for memberParty in memberParties {
                if !allParties.contains(where: { $0.id == memberParty.id }) {
                    allParties.append(memberParty)
                }
            }
            
            // Fetch game dates to check for expiration
            let gameIds = allParties.map { Int($0.game_id) }
            struct GameInfo: Codable, Hashable { let id: Int64; let date: String }
            let gamesResponse: [GameInfo] = try await supabaseClient
                .from("Game")
                .select("id, date")
                .in("id", values: gameIds)
                .execute()
                .value
            
            let gameIdToDate = Dictionary(uniqueKeysWithValues: gamesResponse.map { ($0.id, $0.date) })
            
            // Remove the filter that hides expired parties
            // Instead, compute isExpired for each party
            let now = Date()
            let partiesWithStatus: [(Party, Bool)] = allParties.map { party in
                guard let gameDateString = gameIdToDate[party.game_id],
                      let gameDate = ISO8601DateFormatter().date(from: gameDateString) else {
                    return (party, false)
                }
                let isExpired = gameDate < now
                return (party, isExpired)
            }
            
            print("✅ Successfully loaded \(partiesWithStatus.count) parties")

            // --- Fetch member counts for all parties ---
            let partyIds = partiesWithStatus.map { Int($0.0.id) }
            var memberCounts: [Int64: Int] = [:]
            if !partyIds.isEmpty {
                let membersResponse = try await supabaseClient
                    .from("Party Members")
                    .select("party_id")
                    .in("party_id", values: partyIds)
                    .execute()
                struct MemberRow: Codable { let party_id: Int64 }
                let decoder = JSONDecoder()
                let memberRows = try decoder.decode([MemberRow].self, from: membersResponse.data)
                memberCounts = Dictionary(grouping: memberRows, by: { $0.party_id }).mapValues { $0.count }
            }

            let memberCountsToAssign = memberCounts
            await MainActor.run {
                self.parties = partiesWithStatus.map { $0.0 }
                self.isLoading = false
                self.memberCounts = memberCountsToAssign
                self.partyStatuses = Dictionary(uniqueKeysWithValues: partiesWithStatus.map { ($0.0.id, $0.1) })
            }
            
            // Fetch all party codes for global duplicate check
            print("🔍 Fetching all party codes for global duplicate check...")
            let allCodesResponse = try await supabaseClient
                .from("Parties")
                .select("party_code")
                .execute()
            let allCodesData = String(data: allCodesResponse.data, encoding: .utf8) ?? "No data"
            print("🔍 All party codes in DB:", allCodesData)
            
        } catch {
            print("❌ Error loading parties:")
            print("❌ Error type:", type(of: error))
            print("❌ Error description:", error.localizedDescription)
            if let decodingError = error as? DecodingError {
                print("❌ Decoding error details:", decodingError)
            }
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
    let isOngoing: Bool
    let isExpired: Bool
    let sport: String
    let betType: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.party_name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Text("Members: \(memberCount)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        if isExpired {
                            Text("Expired")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                        } else {
                            Text(isOngoing ? "Ongoing" : "Completed")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isOngoing ? .green : .gray)
                        }
                        Text(sport)
                            .font(.system(size: 14, weight: .medium))
                    }
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
