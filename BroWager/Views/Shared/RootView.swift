import SwiftUI

struct RootView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var navPath = NavigationPath()
    @State private var showChooseUsername = false
    @State private var selectedTab: Int = 2

    // Force NavigationStack to update when login state changes
    var loginKey: String {
        "\(sessionManager.isLoggedIn)-\(sessionManager.userEmail ?? "")-\(sessionManager.needsUsername)"
    }

    // Helper view to add swipe gesture to tab content
    struct SwipeGestureView<Content: View>: View {
        let selectedTab: Int
        let setTab: (Int) -> Void
        let content: () -> Content
        var body: some View {
            content()
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            if abs(value.translation.width) > abs(value.translation.height) {
                                if value.translation.width < 0 && selectedTab < 4 {
                                    setTab(selectedTab + 1)
                                } else if value.translation.width > 0 && selectedTab > 0 {
                                    setTab(selectedTab - 1)
                                }
                            }
                        }
                )
        }
    }

    var body: some View {
        Group {
            if sessionManager.isLoggedIn, let email = sessionManager.userEmail, !sessionManager.needsUsername {
                ZStack {
                    TabView(selection: $selectedTab) {
                        SwipeGestureView(selectedTab: selectedTab, setTab: { selectedTab = $0 }) {
                            MyPartiesView(email: email)
                        }
                        .tabItem { Label("My Parties", systemImage: "person.3.fill") }
                        .tag(0)
                        SwipeGestureView(selectedTab: selectedTab, setTab: { selectedTab = $0 }) {
                            FriendsView(email: email)
                        }
                        .tabItem { Label("Friends", systemImage: "person.2.fill") }
                        .tag(1)
                        SwipeGestureView(selectedTab: selectedTab, setTab: { selectedTab = $0 }) {
                            NavigationStack {
                                BetTypeView(navPath: $navPath, email: email)
                            }
                        }
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(2)
                        SwipeGestureView(selectedTab: selectedTab, setTab: { selectedTab = $0 }) {
                            LeaderBoardView()
                        }
                        .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
                        .tag(3)
                        SwipeGestureView(selectedTab: selectedTab, setTab: { selectedTab = $0 }) {
                            ProfileView(navPath: .constant(NavigationPath()), email: email)
                        }
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                        .tag(4)
                    }
                }
            } else {
                NavigationStack(path: $navPath) {
                    LoginSignupView()
                }
            }
        }
        .id(loginKey)
        .onAppear {
            selectedTab = 2 // Home tab by default
            print("[RootView] SessionManager instance: \(Unmanaged.passUnretained(sessionManager).toOpaque())")
            Task {
                await sessionManager.refreshSession()
            }
            // Force the sheet to show if needsUsername is true
            DispatchQueue.main.async {
                if sessionManager.needsUsername {
                    showChooseUsername = true
                    print("[RootView] Forced showChooseUsername to true onAppear")
                }
            }
        }
        .onChange(of: sessionManager.isLoggedIn) {
            print("[RootView] isLoggedIn changed: \(sessionManager.isLoggedIn)")
            if sessionManager.isLoggedIn && !sessionManager.needsUsername {
                navPath = NavigationPath()
                selectedTab = 2 // Home tab by default after login
                print("[RootView] navPath reset after login")
            }
        }
        .onChange(of: sessionManager.needsUsername) {
            print("[RootView] needsUsername changed: \(sessionManager.needsUsername)")
            DispatchQueue.main.async {
                showChooseUsername = sessionManager.needsUsername
                print("[RootView] showChooseUsername set to: \(showChooseUsername)")
                if !sessionManager.needsUsername && sessionManager.isLoggedIn {
                    navPath = NavigationPath()
                    print("[RootView] navPath reset after username set")
                }
            }
        }
        .sheet(isPresented: $showChooseUsername) {
            if let userId = sessionManager.newUserId, let email = sessionManager.userEmail {
                ChooseUsernameView(
                    userId: userId,
                    email: email,
                    password: "",
                    onComplete: { _, _ in
                        Task {
                            await sessionManager.refreshSession()
                            showChooseUsername = false
                        }
                    }
                )
            }
        }
    }
} 