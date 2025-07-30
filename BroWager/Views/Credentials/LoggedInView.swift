import Foundation
import SwiftUI
import Supabase

struct LoggedInView: View {
    @Binding var navPath: NavigationPath
    @State var email: String
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @EnvironmentObject var sessionManager: SessionManager

    enum Tab: Int, CaseIterable {
        case home, myParties, friends, leaderboard, profile
        
        var title: String {
            switch self {
            case .home: return "Home"
            case .myParties: return "My Parties"
            case .friends: return "Friends"
            case .leaderboard: return "Leaderboard"
            case .profile: return "Profile"
            }
        }
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        ZStack {
            // Background
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
                // Header with tab indicators
                VStack(spacing: 16) {
                    HStack {
                        Text("BroWager")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    
                    // Tab indicator dots
                    HStack(spacing: 12) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Circle()
                                .fill(selectedTab == tab ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(selectedTab == tab ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding(.top, 16)

                // Content view - no swiping
                Group {
                    switch selectedTab {
                    case .home:
                        HomeTab(navPath: $navPath, email: email)
                    case .myParties:
                        MyPartiesView(email: email)
                    case .friends:
                        FriendsView(email: email)
                    case .leaderboard:
                        LeaderBoardView()
                    case .profile:
                        ProfileView(navPath: $navPath, email: email)
                    }
                }
            }

            // Floating profile button
            ProfileIconOverlay(showProfile: { showProfile = true }, profileImage: profileImage)
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: $navPath, email: email)
        }
        .onAppear {
            Task {
                profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
            }
        }
    }
}

struct HomeTab: View {
    @Binding var navPath: NavigationPath
    var email: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HomeCard(
                    title: "My Parties",
                    subtitle: "View and manage your active parties",
                    icon: "ticket.fill",
                    gradient: [Color.blue, Color.blue.opacity(0.8)],
                    action: { navPath.append(LoggedInPath.myParties) }
                )

                HomeCard(
                    title: "Friends",
                    subtitle: "View and manage your friends",
                    icon: "person.2.fill",
                    gradient: [Color.red, Color.red.opacity(0.8)],
                    action: { navPath.append(LoggedInPath.friends) }
                )

                HomeCard(
                    title: "Leaderboard",
                    subtitle: "See who's leading the competition",
                    icon: "trophy.fill",
                    gradient: [Color.yellow, Color.orange],
                    action: { navPath.append(LoggedInPath.leaderboard) }
                )

                Button(action: {
                    navPath.append(LoggedInPath.betType)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                        Text("Create New Bet")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct HomeCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var gradient: [Color]
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(gradient: Gradient(colors: gradient), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LoggedInView(
        navPath: .constant(NavigationPath()),
        email: "test@example.com"
    )
    .environment(\.supabaseClient, .development)
}
