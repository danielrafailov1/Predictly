import SwiftUI
import Supabase

struct FriendsView: View {
    let email: String
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    @State private var openParties: [PartyData] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var searchText: String = ""
    
    struct PartyData: Identifiable, Codable {
        let id: Int64
        let party_name: String
        let bet: String
        let bet_type: String?
        let options: [String]?
        let max_members: Int64?
        let privacy_option: String?
        let status: String?
        let created_by: String
        let created_at: String?
        let terms: String?
        
        var displayOptions: String {
            return options?.joined(separator: ", ") ?? "No options available"
        }
        
        var memberLimit: String {
            if let max = max_members {
                return "Max: \(max) members"
            }
            return "No member limit"
        }
    }
    
    var filteredParties: [PartyData] {
        if searchText.isEmpty {
            return openParties
        }
        
        let lowercaseSearch = searchText.lowercased()
        return openParties.filter { party in
            party.bet.lowercased().contains(lowercaseSearch) ||
            party.party_name.lowercased().contains(lowercaseSearch) ||
            party.options?.joined(separator: " ").lowercased().contains(lowercaseSearch) == true ||
            party.bet_type?.lowercased().contains(lowercaseSearch) == true
        }
    }
    
    var body: some View {
        NavigationView {
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
                    // Header
                    VStack(spacing: 12) {
                        Text("Open Parties")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Find and join betting parties")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search parties, bets, or options...", text: $searchText)
                            .foregroundColor(.white)
                            .accentColor(.blue)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView("Loading open parties...")
                            .tint(.white)
                            .foregroundColor(.white)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            
                            Text("Error")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(error)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            Button("Retry") {
                                loadOpenParties()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding()
                        Spacer()
                    } else if filteredParties.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: searchText.isEmpty ? "person.3" : "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text(searchText.isEmpty ? "No Open Parties" : "No Results")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(searchText.isEmpty ? "There are no open parties available to join right now." : "No parties match your search.")
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        Spacer()
                    } else {
                        // Parties list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredParties) { party in
                                    OpenPartyCardView(party: party)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadOpenParties()
        }
        .refreshable {
            loadOpenParties()
        }
    }
    
    private func loadOpenParties() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await supabaseClient
                    .from("Parties")
                    .select()
                    .eq("privacy_option", value: "public")
                    .eq("status", value: "open")
                    .order("created_at", ascending: false)
                    .execute()
                
                let decoder = JSONDecoder()
                let parties = try decoder.decode([PartyData].self, from: response.data)
                
                await MainActor.run {
                    self.openParties = parties
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load parties: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct OpenPartyCardView: View {
    let party: FriendsView.PartyData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(party.party_name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Text(party.memberLimit)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        if let betType = party.bet_type {
                            Text(betType.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.3))
                                .foregroundColor(.blue.opacity(0.8))
                                .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
                
                // For now, just show a placeholder join button
                Text("Available")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(20)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Bet description
            VStack(alignment: .leading, spacing: 8) {
                Text("Bet")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(party.bet)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(3)
            }
            
            // Options if available
            if !party.displayOptions.isEmpty && party.displayOptions != "No options available" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Options")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(party.displayOptions)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
            }
            
            // Terms if available
            if let terms = party.terms, !terms.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Terms")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(terms)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
