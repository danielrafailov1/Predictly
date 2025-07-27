import SwiftUI

struct BetTypeView: View {
    @Binding var navPath: NavigationPath
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBetType: BetType?
    let email: String
    @State private var showProfile = false
    @State private var profileImage: Image? = nil
    @Environment(\.supabaseClient) private var supabaseClient
    @State private var tutorialBetType: BetType? = nil
    @State private var userId: UUID? = nil

    enum BetType: String, CaseIterable, Identifiable, Equatable {
        case normal = "Normal"
        case timed = "Timed"
        case contest = "Contest"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .normal: return "sportscourt.fill"
            case .timed: return "clock.fill"
            case .contest: return "heart.fill"
            }
        }

        var description: String {
            switch self {
            case .normal: return "Bet on anything"
            case .timed: return "Bet on timed challenges and competitions"
            case .contest: return "Bet on who can do something the fastest"
            }
        }

        var isEnabled: Bool { true }
    }
    
    private func path(for betType: BetType) -> BetTypePath {
        switch betType {
        case .normal: return .normal
        case .timed: return .timed
        case .contest: return .contest
        }
    }


    enum BetTypePath: String, Hashable {
        case normal
        case timed
        case contest
    }

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

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Choose Bet Type")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Select the type of bet you want to make")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        if userId != nil {
                            ForEach(BetType.allCases, id: \.self) { betType in
                                NavigationLink(value: path(for: betType)) {
                                    BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                }
                            }
                        } else {
                            ProgressView("Loading user...")
                                .padding()
                        }

                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }

                Spacer()
            }
            .navigationDestination(for: BetTypePath.self) { path in
                switch path {
                case .normal:
                    NormalBetView(navPath: $navPath, email: email, userId: userId)
                case .timed:
                    TimedBetSettingView()
                case .contest:
                    ContestBetView(navPath: $navPath, email: email)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView(navPath: $navPath, email: email)
            }
            .sheet(item: $tutorialBetType) { betType in
                VStack(spacing: 24) {
                    Image(systemName: betType.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .padding(.top, 32)

                    Text(betType.rawValue)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text(betType.description)
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()

                    Button("Got it!") { tutorialBetType = nil }
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 48)
                        .background(Color.blue)
                        .cornerRadius(14)
                        .padding(.bottom, 32)
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                Task {
                    profileImage = await fetchProfileImage(for: email, supabaseClient: supabaseClient)
                    await fetchUserId()
                }
            }
        }
    }

    private func fetchUserId() async {
        do {
            let loginInfos: [LoginInfo] = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
                .value
            
            print(loginInfos)


            if let loginInfo = loginInfos.first {
                userId = UUID(uuidString: loginInfo.user_id)
            } else {
                print("No user found with that email")
            }
        } catch {
            print("Error fetching userId: \(error)")
        }
    }

    struct BetTypeCard: View {
        let betType: BetTypeView.BetType
        var showTutorial: () -> Void = {}

        var body: some View {
            HStack(alignment: .top, spacing: 20) {
                Image(systemName: betType.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(betType.rawValue)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Button(action: showTutorial) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(betType.description)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(3)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.13), lineWidth: 1.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    NavigationView {
        BetTypeView(navPath: .constant(NavigationPath()), email: "test@example.com")
    }
}
