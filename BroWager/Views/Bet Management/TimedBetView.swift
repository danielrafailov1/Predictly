import SwiftUI

struct TimedBetView: View {
    let email: String
    var body: some View {
        VStack {
            Text("Timed Bet View")
                .font(.largeTitle)
                .padding()
            Text("Email: \(email)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 