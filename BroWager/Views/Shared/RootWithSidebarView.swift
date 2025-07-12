import SwiftUI

struct RootWithSidebarView: View {
    @State private var sidebarSelection: SidebarItem? = nil
    let email: String
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection, email: email)
        } detail: {
            // Main content placeholder; replace with your main app view
            Text("Select an item from the sidebar")
                .foregroundColor(.secondary)
                .font(.title2)
        }
    }
} 