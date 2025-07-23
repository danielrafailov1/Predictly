import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let email: String
    var body: some View {
        List(selection: $selection) {
            NavigationLink(destination: ProfileView(navPath: .constant(NavigationPath()), email: email), tag: SidebarItem.profile, selection: $selection) {
                Label("Profile", systemImage: "person.crop.circle")
            }
            // Add more sidebar items here as needed
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Menu")
    }
}

enum SidebarItem: Hashable {
    case profile
    // Add more cases as needed
} 
