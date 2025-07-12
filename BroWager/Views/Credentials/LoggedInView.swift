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
                // Header
                HStack {
                    Text("BroWager")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)

                // Main Content
                ScrollView {
                    VStack(spacing: 24) {
                        // My Bets Card
                        Button(action: {
                            navPath.append(LoggedInPath.myParties)
                        }) {
                            HStack(spacing: 20) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.blue,
                                                Color.blue.opacity(0.8)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("My Parties")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("View and manage your active parties")
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

                        // Friends Button
                        Button(action: {
                            navPath.append(LoggedInPath.friends)
                        }) {
                            HStack(spacing: 20) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.red,
                                                Color.red.opacity(0.8)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Friends")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("View and manage your friends")
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

                        // Leaderboard Card
                        Button(action: {
                            navPath.append(LoggedInPath.leaderboard)
                        }) {
                            HStack(spacing: 20) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.yellow,
                                                Color.orange
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Leaderboard")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("See who's leading the competition")
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
                    .padding(.horizontal, 24)
                }

                // Create Bet Button
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
                            gradient: Gradient(colors: [
                                Color.green,
                                Color.green.opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            // Overlay profile icon
            ProfileIconOverlay(showProfile: { showProfile = true }, profileImage: profileImage)
        }
        .navigationDestination(for: LoggedInPath.self) { path in
            switch path {
            case .profile:
                ProfileView(navPath: $navPath, email: email)
                    .environment(\.supabaseClient, supabaseClient)
            case .myParties:
                MyPartiesView(email: email)
            case .leaderboard:
                LeaderBoardView()
            case .betType:
                BetTypeView(navPath: $navPath, email: email)
            case .friends:
                FriendsView(email: email)
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(navPath: $navPath, email: email)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            Task {
                profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
            }
        }
    }
}

#Preview {
    LoggedInView(
        navPath: .constant(NavigationPath()),
        email: "test@example.com"
    )
    .environment(\.supabaseClient, .development)
}
