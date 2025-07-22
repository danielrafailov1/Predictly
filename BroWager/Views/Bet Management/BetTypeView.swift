import SwiftUI

struct BetTypeView: View {
    @Binding var navPath: NavigationPath
    let email: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBetType: BetType?
    
    enum BetType: String, CaseIterable, Identifiable {
        case normal = "Normal"
        case timed = "Timed"
        case contest = "Contest"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .normal: return "circle.fill"
            case .timed: return "clock.fill"
            case .contest: return "flag.checkered"
            }
        }
        var description: String {
            switch self {
            case .normal: return "A standard bet with no time constraints."
            case .timed: return "A bet that must be completed within a certain time."
            case .contest: return "A competitive bet with multiple participants."
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
                        let betTypes: [BetType] = [.normal, .timed, .contest]
                        ForEach(betTypes, id: \.self) { betType in
                            let path: BetTypePath = {
                                switch betType {
                                case .normal: return .normal
                                case .timed: return .timed
                                case .contest: return .contest
                                }
                            }()
                            NavigationLink(value: path) {
                                HStack {
                                    Image(systemName: betType.icon)
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(Color.blue.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(betType.rawValue)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(betType.description)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    Spacer()
                                }
                                .padding(20)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.07)))
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
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
                    NormalBetView(email: email)
                case .timed:
                    TimedBetView(email: email)
                case .contest:
                    ContestBetView(email: email)
                }
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
    }
}

#Preview {
    NavigationView {
        BetTypeView(navPath: .constant(NavigationPath()), email: "")
    }
} 
