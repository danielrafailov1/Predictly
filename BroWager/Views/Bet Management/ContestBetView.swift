import SwiftUI

struct ContestBetView: View {
    let email: String
    var body: some View {
        VStack {
            Text("Contest Bet View")
                .font(.largeTitle)
                .padding()
            Text("Email: \(email)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 