import SwiftUI
import Combine
import Supabase

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    private let client = SupabaseConfig.client
    
    // Stores messages grouped by Trade ID
    @Published var conversations: [UUID: [Message]] = [:]
    @Published var currentUserId: UUID?
    
    // Connection Status
    @Published var isConnected = false
    
    private var channel: RealtimeChannelV2?
    private var isSetup = false
    
    private init() {
        Task {
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
        
        // 1. Initial Sync (Inbox)
        await fetchInbox(userId: userId)
        
        // 2. Realtime Listener
        await subscribeToRealtime(userId: userId)
    }
    
    // MARK: - Actions
    
    @MainActor
    func sendMessage(_ text: String, to receiverId: UUID, tradeId: UUID? = nil, imageUrl: String? = nil) async {
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
        
        // Optimistic UI Update (Snappy!)
        appendMessage(newMessage)
        
        do {
            try await client.from("messages").insert(newMessage).execute()
        } catch {
            print("❌ Failed to send message: \(error)")
            // Optional: Mark message as failed in UI
        }
    }
    
    @MainActor
    func sendSystemMessage(_ actionType: String, to receiverId: UUID, tradeId: UUID) async {
        // System actions are special codes handled by the UI
        let content = "ACTION:\(actionType)"
        await sendMessage(content, to: receiverId, tradeId: tradeId)
    }
    
    @MainActor
    func sendImage(data: Data, to receiverId: UUID, tradeId: UUID) async {
        guard let myId = currentUserId else { return }
        
        do {
            // 📉 COST OPTIMIZATION: Compression should happen before calling this
            let filename = "\(myId)/\(UUID().uuidString).jpg"
            
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
    
    /// Fetches the inbox state.
    /// 📉 OPTIMIZATION: Limits to recent history to prevent fetching 10k messages on load.
    @MainActor
    func fetchInbox(userId: UUID) async {
        do {
            // Fetch last 100 messages for the inbox preview
            // For a production app, you'd use a specific "latest_messages" view in SQL
            let messages: [Message] = try await client
                .from("messages")
                .select()
                .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
                .order("created_at", ascending: false) // Newest first
                .limit(50) // Limit to save data
                .execute()
                .value
            
            // Re-sort for display (Oldest first)
            let sorted = messages.sorted { $0.createdAt < $1.createdAt }
            self.conversations = Dictionary(grouping: sorted) { $0.tradeId ?? UUID() }
            
        } catch {
            print("❌ Error fetching inbox: \(error)")
        }
    }
    
    /// ✨ NEW: targeted fetch for a single room.
    /// Call this when entering a specific chat to ensure we have the FULL history for that trade.
    @MainActor
    func loadChat(tradeId: UUID) async {
        do {
            let messages: [Message] = try await client
                .from("messages")
                .select()
                .eq("trade_id", value: tradeId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            self.conversations[tradeId] = messages
        } catch {
            print("❌ Error loading chat room: \(error)")
        }
    }
    
    func subscribeToRealtime(userId: UUID) async {
        if let existingChannel = channel { await existingChannel.unsubscribe() }
        
        // Channel scoped to public messages
        // 🔒 SECURITY: We filter by receiver_id so we don't get everyone's messages
        let newChannel = client.channel("public:messages")
        self.channel = newChannel
        
        let changeStream = newChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "messages",
            // ✨ FIX: Use typed .eq filter builder instead of raw string to silence warning
            filter: .eq("receiver_id", value: userId)
        )
        
        do {
            try await newChannel.subscribeWithError()
            await MainActor.run { self.isConnected = true }
        } catch {
            print("⚠️ Realtime connection failed, retrying...")
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            await subscribeToRealtime(userId: userId)
            return
        }
        
        Task {
            for await action in changeStream {
                guard let myId = await MainActor.run(body: { return self.currentUserId }) else { continue }
                
                await MainActor.run {
                    switch action {
                    case .insert(let insertAction):
                        do {
                            let data = try JSONEncoder().encode(insertAction.record)
                            let message = try JSONDecoder().decode(Message.self, from: data)
                            self.appendMessage(message)
                            
                            // Trigger Local Notification if backgrounded
                            if message.senderId != myId {
                                NotificationManager.shared.sendLocalNotification(
                                    title: "New Message",
                                    body: message.content.hasPrefix("ACTION:") ? "New Update on your trade" : "You have a new message"
                                )
                            }
                        } catch {
                            print("⚠️ Failed to decode realtime message: \(error)")
                        }
                    default:
                        break
                    }
                }
            }
            await MainActor.run { self.isConnected = false }
        }
    }
    
    @MainActor
    private func appendMessage(_ message: Message) {
        guard let tradeId = message.tradeId else { return }
        
        if conversations[tradeId] == nil {
            conversations[tradeId] = []
        }
        
        // Prevent duplicates
        if !(conversations[tradeId]?.contains(where: { $0.id == message.id }) ?? false) {
            conversations[tradeId]?.append(message)
            // Ensure strictly sorted by time
            conversations[tradeId]?.sort { $0.createdAt < $1.createdAt }
        }
    }
}
