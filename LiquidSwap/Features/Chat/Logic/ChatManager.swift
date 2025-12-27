import SwiftUI
import Combine
import Supabase

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    private let client = SupabaseConfig.client
    
    // Stores messages grouped by Trade ID
    @Published var conversations: [UUID: [Message]] = [:]
    @Published var currentUserId: UUID?
    
    // Connection Status (Useful for UI debugging)
    @Published var isConnected = false
    
    private var channel: RealtimeChannelV2?
    private var isSetup = false
    
    private init() {
        Task {
            // Listen for Auth changes
            for await state in client.auth.authStateChanges {
                if let session = state.session {
                    await MainActor.run { self.currentUserId = session.user.id }
                    await setup(userId: session.user.id)
                } else {
                    await reset()
                }
            }
        }
    }
    
    @MainActor
    func reset() async {
        conversations = [:]
        currentUserId = nil
        isConnected = false
        isSetup = false
        if let channel = channel {
            await channel.unsubscribe()
            self.channel = nil
        }
    }
    
    func setup(userId: UUID) async {
        if isSetup { return }
        isSetup = true
        print("💬 ChatManager: Setting up for \(userId)...")
        
        // 1. Initial Load
        await fetchAllMessages(userId: userId)
        
        // 2. Start Realtime Listener
        await subscribeToRealtime()
    }
    
    // MARK: - Actions
    
    @MainActor
    func sendMessage(_ text: String, to receiverId: UUID, tradeId: UUID, imageUrl: String? = nil) async {
        guard let myId = currentUserId else { return }
        
        let newMessage = Message(
            id: UUID(),
            senderId: myId,
            receiverId: receiverId,
            content: text,
            createdAt: Date(),
            imageUrl: imageUrl,
            tradeId: tradeId
        )
        
        // Optimistic Update (Show immediately)
        appendMessage(newMessage)
        
        do {
            try await client.from("messages").insert(newMessage).execute()
            print("✅ Message sent to DB")
        } catch {
            print("❌ Failed to send message: \(error)")
            // Optional: Add "retry" logic or remove from UI here
        }
    }
    
    @MainActor
    func sendImage(data: Data, to receiverId: UUID, tradeId: UUID) async {
        guard let myId = currentUserId else { return }
        
        do {
            let filename = "\(myId)/\(Int(Date().timeIntervalSince1970)).jpg"
            let _ = try await client.storage
                .from("chat-images")
                .upload(filename, data: data, options: FileOptions(contentType: "image/jpeg"))
            
            let projectUrl = SupabaseConfig.supabaseURL.absoluteString
            let publicUrl = "\(projectUrl)/storage/v1/object/public/chat-images/\(filename)"
            
            await sendMessage("Sent an image", to: receiverId, tradeId: tradeId, imageUrl: publicUrl)
        } catch {
            print("❌ Failed to upload image: \(error)")
        }
    }
    
    @MainActor
    func deleteConversation(tradeId: UUID) async {
        do {
            try await client.from("messages").delete().eq("trade_id", value: tradeId).execute()
            conversations.removeValue(forKey: tradeId)
        } catch {
            print("❌ Failed to delete chat: \(error)")
        }
    }
    
    // MARK: - Fetching & Realtime
    
    @MainActor
    func fetchAllMessages(userId: UUID) async {
        do {
            let messages: [Message] = try await client
                .from("messages")
                .select()
                .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
                .order("created_at", ascending: true)
                .execute()
                .value
            
            self.conversations = Dictionary(grouping: messages) { $0.tradeId ?? UUID() }
            print("✅ ChatManager: Loaded \(messages.count) total messages.")
        } catch {
            print("❌ Error fetching messages: \(error)")
        }
    }
    
    func subscribeToRealtime() async {
            if let existingChannel = channel { await existingChannel.unsubscribe() }
            
            let newChannel = client.channel("public:messages")
            self.channel = newChannel
            
            // Listen for INSERT events (New Messages)
            let changeStream = newChannel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "messages"
            )
            
            do {
                try await newChannel.subscribeWithError()
                await MainActor.run { self.isConnected = true }
                print("✅ Realtime Connected!")
            } catch {
                print("⚠️ Realtime connection failed: \(error). Retrying in 5s...")
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                await subscribeToRealtime()
                return
            }
            
            Task {
                for await _ in changeStream {
                    // 1. Refresh Data
                    if let id = await MainActor.run(body: { return self.currentUserId }) {
                        await fetchAllMessages(userId: id)
                        
                        // 2. ✨ TRIGGER NOTIFICATION ✨
                        await MainActor.run {
                            // Logic: Only notify if it's NOT a message I just sent
                            // (We assume the last message in the fetched list is the new one)
                            // A simple generic notification works for now:
                            NotificationManager.shared.sendLocalNotification(
                                title: "New Message",
                                body: "You received a new message on LiquidSwap!"
                            )
                        }
                    }
                }
                await MainActor.run { self.isConnected = false }
            }
        }
    
    private func appendMessage(_ message: Message) {
        guard let tradeId = message.tradeId else { return }
        if conversations[tradeId] == nil { conversations[tradeId] = [] }
        conversations[tradeId]?.append(message)
    }
}
