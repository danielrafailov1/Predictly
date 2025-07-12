import SwiftUI
import Supabase

struct PartyChatView: View {
    let partyId: Int64
    let partyName: String
    @Environment(\.supabaseClient) private var supabaseClient
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var newMessage: String = ""
    @State private var isLoading = true
    @State private var error: String? = nil
    @State private var scrollToBottom = false
    @State private var username: String = ""
    @State private var userId: String? = nil
    @State private var profileImages: [String: Image?] = [:]
    // Live polling
    @State private var messageTimer: Timer? = nil
    // Typing indicator (local demo)
    @State private var isTyping = false
    @State private var otherUserTyping = false
    @State private var lastTypedAt: Date = Date()
    
    struct ChatMessage: Identifiable, Codable, Equatable {
        let id: Int64
        let party_id: Int64
        let user_id: String
        let username: String
        let message: String
        let created_at: String
    }
    
    struct NewChatMessage: Codable {
        let party_id: Int64
        let user_id: String
        let username: String
        let message: String
        let created_at: String
    }
    
    struct ChatMessageRow: View {
        let msg: PartyChatView.ChatMessage
        let isSelf: Bool
        let profileImage: Image?
        var body: some View {
            HStack(alignment: .bottom, spacing: 8) {
                if !isSelf {
                    (profileImage ?? Image(systemName: "person.crop.circle.fill"))
                        .resizable()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
                if isSelf { Spacer(minLength: 40) }
                VStack(alignment: isSelf ? .trailing : .leading, spacing: 2) {
                    HStack(alignment: .bottom, spacing: 4) {
                        if !isSelf {
                            Text(msg.username)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Text(shortTime(msg.created_at))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Text(msg.message)
                        .padding(10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .frame(maxWidth: 260, alignment: isSelf ? .trailing : .leading)
                }
                if isSelf {
                    (profileImage ?? Image(systemName: "person.crop.circle.fill"))
                        .resizable()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
                if !isSelf { Spacer(minLength: 40) }
            }
        }
        func shortTime(_ iso: String) -> String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: iso) {
                let output = DateFormatter()
                output.timeStyle = .short
                output.dateStyle = .none
                return output.string(from: date)
            }
            return ""
        }
    }
    
    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(messages) { msg in
                        let isSelf = msg.user_id == (userId ?? "")
                        ChatMessageRow(msg: msg, isSelf: isSelf, profileImage: profileImages[msg.user_id] ?? nil)
                            .id(msg.id)
                    }
                    // Typing indicator
                    if otherUserTyping {
                        HStack {
                            Text("Someone is typing...")
                                .italic()
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onAppear { Task { await loadProfileImagesForMessages() } }
            .onChange(of: messages) { _ in Task { await loadProfileImagesForMessages() } }
            .onChange(of: userId) { _ in Task { await loadProfileImagesForMessages() } }
            .onChange(of: messages.count) { _ in
                if let last = messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Party Chat: \(partyName)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.8))
            if isLoading {
                ProgressView().padding()
            } else if let error = error {
                Text(error).foregroundColor(.red).padding()
            } else {
                messageList
            }
            HStack {
                if username.isEmpty {
                    if let error = error, error.contains("username") {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        ProgressView("Loading username...")
                            .padding()
                    }
                } else {
                    TextField("Type a message...", text: $newMessage, onEditingChanged: { editing in
                        if editing {
                            isTyping = true
                            lastTypedAt = Date()
                        } else {
                            isTyping = false
                        }
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 36)
                    .onChange(of: newMessage) { _ in
                        isTyping = true
                        lastTypedAt = Date()
                    }
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(newMessage.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty || username.isEmpty)
                }
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.15, green: 0.15, blue: 0.25)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        )
        .onAppear {
            Task { await initializeUserIdAndUsername() ; await loadMessages() }
            // Start polling for messages
            messageTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                Task { await loadMessages() }
                // Local demo: fake another user typing if newMessage is not empty and not self
                if !isTyping && !newMessage.isEmpty {
                    otherUserTyping = true
                } else if Date().timeIntervalSince(lastTypedAt) > 2.0 {
                    otherUserTyping = false
                }
            }
        }
        .onDisappear {
            messageTimer?.invalidate()
            messageTimer = nil
        }
    }
    
    func initializeUserIdAndUsername() async {
        // Try sessionManager.newUserId first
        if let sessionUserId = sessionManager.newUserId {
            print("[PartyChatView] Using userId from sessionManager: \(sessionUserId)")
            await MainActor.run { self.userId = sessionUserId }
            await fetchUsername(for: sessionUserId)
            return
        }
        // Fallback: fetch user_id from Login Information using email
        let email = sessionManager.userEmail ?? ""
        guard !email.isEmpty else {
            print("[PartyChatView] No email available for fallback userId fetch")
            await MainActor.run { self.error = "No user ID or email found in session. Please log in again." }
            return
        }
        do {
            let response = try await supabaseClient
                .from("Login Information")
                .select("user_id")
                .eq("email", value: email)
                .limit(1)
                .execute()
            struct UserIdRow: Decodable { let user_id: String }
            let rows = try JSONDecoder().decode([UserIdRow].self, from: response.data)
            if let fetchedUserId = rows.first?.user_id {
                print("[PartyChatView] Fallback loaded userId: \(fetchedUserId)")
                await MainActor.run { self.userId = fetchedUserId }
                await fetchUsername(for: fetchedUserId)
            } else {
                print("[PartyChatView] No user_id found for email: \(email)")
                await MainActor.run { self.error = "No user ID found for your account. Please log in again." }
            }
        } catch {
            print("[PartyChatView] Error fetching user_id by email: \(error)")
            await MainActor.run { self.error = "Error fetching user ID: \(error.localizedDescription)" }
        }
    }
    
    func fetchUsername(for userId: String) async {
        do {
            let response = try await supabaseClient
                .from("Username")
                .select("username")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            print("[PartyChatView] Username fetch response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            struct UsernameRow: Codable { let username: String }
            let rows = try JSONDecoder().decode([UsernameRow].self, from: response.data)
            if let uname = rows.first?.username {
                print("[PartyChatView] Username found: \(uname)")
                await MainActor.run { self.username = uname }
            } else {
                print("[PartyChatView] No username found for userId: \(userId)")
                await MainActor.run { self.error = "No username found for your account. Please set a username in your profile." }
            }
        } catch {
            print("[PartyChatView] Error fetching username: \(error)")
            await MainActor.run { self.error = "Error fetching username: \(error.localizedDescription)" }
        }
    }
    
    func loadMessages() async {
        do {
            let response = try await supabaseClient
                .from("PartyChatMessages")
                .select()
                .eq("party_id", value: Int(partyId))
                .order("created_at", ascending: true)
                .execute()
            let decoder = JSONDecoder()
            let msgs = try decoder.decode([ChatMessage].self, from: response.data)
            await MainActor.run {
                if self.messages != msgs {
                    self.messages = msgs
                }
                if self.isLoading { self.isLoading = false }
            }
        } catch {
            // Only set error if this is the initial load
            await MainActor.run {
                if self.isLoading {
                    self.error = "Failed to load messages: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userId = self.userId, !username.isEmpty else { return }
        let newMsg = NewChatMessage(
            party_id: partyId,
            user_id: userId,
            username: username,
            message: trimmed,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        Task {
            do {
                _ = try await supabaseClient
                    .from("PartyChatMessages")
                    .insert(newMsg)
                    .execute()
                newMessage = ""
                await loadMessages()
            } catch {
                print("Failed to send message: \(error)")
                self.error = "Failed to send message: \(error.localizedDescription)"
            }
        }
    }
    
    func shortTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: iso) {
            let output = DateFormatter()
            output.timeStyle = .short
            output.dateStyle = .none
            return output.string(from: date)
        }
        return ""
    }
    
    func loadProfileImagesForMessages() async {
        for msg in messages {
            if profileImages[msg.user_id] == nil {
                let img = await fetchProfileImageForUserId(msg.user_id)
                await MainActor.run { profileImages[msg.user_id] = img }
            }
        }
    }
    
    func fetchProfileImageForUserId(_ userId: String) async -> Image? {
        let manager = ProfileManager(supabaseClient: supabaseClient)
        do {
            if let urlString = try await manager.fetchProfileImageURL(for: userId),
               let url = URL(string: urlString + "?t=\(Int(Date().timeIntervalSince1970))") {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    return Image(uiImage: uiImage)
                }
            }
        } catch {
            print("Failed to fetch profile image for user_id \(userId): \(error)")
        }
        return nil
    }
} 
