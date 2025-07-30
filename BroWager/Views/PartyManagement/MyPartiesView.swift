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

    let email: String

    @State private var archivedParties: [Party] = []
    @State private var deletedParties: [Party] = []
    @State private var partyFilter: PartyFilter = .active
    @State private var wonPartyIds: Set<Int64> = []
    @State private var lostPartyIds: Set<Int64> = []

    enum PartyFilter: String, CaseIterable, Identifiable {
        case active = "Active"
        case wins = "Wins"
        case losses = "Losses"
        var id: String { rawValue }
    }

    var filteredParties: [Party] {
        switch partyFilter {
        case .active:
            return parties.filter { !wonPartyIds.contains($0.id ?? -1) && !lostPartyIds.contains($0.id ?? -1) }
        case .wins:
            return parties.filter { wonPartyIds.contains($0.id ?? -1) }
        case .losses:
            return parties.filter { lostPartyIds.contains($0.id ?? -1) }
        }
    }

    private var partyRows: [(party: Party, memberCount: Int, betType: String)] {
        let currentMemberCounts = memberCounts
        return filteredParties.compactMap { party in
            guard let id = party.id else { return nil }
            return (
                party: party,
                memberCount: currentMemberCounts[id] ?? 1,
                betType: party.bet_type ?? ""
            )
        }
    }

    private var partyListSection: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Retry") {
                        Task {
                            await loadParties()
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredParties.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No \(partyFilter.rawValue.lowercased()) parties")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    if partyFilter == .active {
                        Text("Create a new party to get started")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(partyRows, id: \.party.id) { row in
                        NavigationLink(value: PartyNavigation(partyCode: row.party.party_code ?? "", email: email)) {
                            PartyCard(
                                party: row.party,
                                memberCount: row.memberCount,
                                betType: row.betType,
                                backgroundColor: wonPartyIds.contains(row.party.id ?? -1) ? Color.green.opacity(0.2) :
                                                 lostPartyIds.contains(row.party.id ?? -1) ? Color.red.opacity(0.2) :
                                                 Color.white.opacity(0.08)
                            )
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
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
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.15, green: 0.15, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
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

                    Picker("Party Filter", selection: $partyFilter) {
                        ForEach(PartyFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 14)

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

                    partyListSection
                }
            }
            .navigationDestination(for: PartyNavigation.self) { details in
                PartyDetailsView(partyCode: details.partyCode, email: details.email)
            }
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

    func loadParties() async {
        isLoading = true
        errorMessage = nil
        
        struct PartyRow: Decodable {
            let id: Int64
            let party_name: String
            let bet_type: String?
            let party_code: String?
            let created_by: String?
        }
        struct WinRow: Decodable { let party_id: Int64 }

        do {
            // Fetch parties
            let partiesResponse = try await supabaseClient
                .from("Parties")
                .select("id, party_name, bet_type, party_code, created_by")
                .execute()
            let partiesData = partiesResponse.data
            let parties = try JSONDecoder().decode([PartyRow].self, from: partiesData)
            
            // Fetch winning party IDs for this user
            let userWinsResponse = try await supabaseClient
                .from("User Bets")
                .select("party_id")
                .eq("user_id", value: userId)
                .eq("is_winner", value: true)
                .execute()
            let winsData = userWinsResponse.data
            let winRows = try JSONDecoder().decode([WinRow].self, from: winsData)
            let winPartyIds = Set(winRows.map { $0.party_id })
            
            // Fetch losing party IDs for this user
            let userLossesResponse = try await supabaseClient
                .from("User Bets")
                .select("party_id")
                .eq("user_id", value: userId)
                .eq("is_winner", value: false)
                .execute()
            let lossesData = userLossesResponse.data
            let lossRows = try JSONDecoder().decode([WinRow].self, from: lossesData)
            let lossPartyIds = Set(lossRows.map { $0.party_id })
            
            let loadedParties = parties.map { p in
                Party(
                    id: p.id,
                    party_name: p.party_name ?? "",
                    party_code: p.party_code ?? "",
                    created_by: p.created_by ?? "",
                    bet_type: p.bet_type,
                    max_members: nil,
                    status: nil,
                    created_at: nil,
                    bet: nil,
                    terms: nil,
                    options: nil,
                    game_status: nil,
                    privacy_option: nil
                )
            }
            
            DispatchQueue.main.async {
                self.parties = loadedParties
                self.wonPartyIds = winPartyIds
                self.lostPartyIds = lossPartyIds
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "Error loading parties: \(error.localizedDescription)"
                isLoading = false
            }
            print("Error loading parties: \(error)")
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
            struct CreatorInfo: Codable { let email: String }
            let info = try JSONDecoder().decode([CreatorInfo].self, from: response.data)
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
    let backgroundColor: Color

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
        .background(backgroundColor)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    MyPartiesView(email: "example@example.com")
        .environment(\.supabaseClient, .development)
}
