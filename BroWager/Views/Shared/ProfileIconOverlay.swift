import SwiftUI

struct ProfileIconOverlay: View {
    let showProfile: () -> Void
    let profileImage: Image?
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: showProfile) {
                    if let image = profileImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 13)
            }
            Spacer(minLength: 0)
        }
    }
} 
