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
    
    enum BetType: String, CaseIterable, Identifiable {
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
        
        var isEnabled: Bool {
            switch self {
            case .normal: return true
            case .timed: return true
            case .contest: return true
            }
        }
    }
    
    enum BetTypePath: Hashable {
        case normal
        case timed
        case contest
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
            
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Bet Type")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Select the type of bet you want to make")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 16)
                
                // Bet Type Options
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(BetType.allCases, id: \ .self) { betType in
                            if betType.isEnabled {
                                switch betType {
                                case .normal:
                                    NavigationLink(value: BetTypePath.normal) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                case .timed:
                                    NavigationLink(value: BetTypePath.timed) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                case .contest:
                                    NavigationLink(value: BetTypePath.contest) {
                                        BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    }
                                }
                            } else {
                                BetTypeCard(betType: betType, showTutorial: { tutorialBetType = betType })
                                    .opacity(0.5)
                            }
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
                    NormalBetView(navPath: $navPath, email: email)
                case .timed:
                    TimedBetSettingView()
                case .contest:
                    ContestBetView(navPath: $navPath, email: email)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
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
                }
            }
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
                            gradient: Gradient(colors: [
                                Color.blue,
                                Color.blue.opacity(0.8)
                            ]),
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
                            .fixedSize(horizontal: false, vertical: true)
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
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if betType.isEnabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
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
