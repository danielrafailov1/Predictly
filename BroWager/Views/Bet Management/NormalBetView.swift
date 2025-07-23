import SwiftUI

struct NormalBetView: View {
    let email: String
    var body: some View {
        VStack {
            Text("Normal Bet View")
                .font(.largeTitle)
                .padding()
            Text("Email: \(email)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 