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
    
    // MARK: - ✨ Message Validation State (Issue #7 Fix)
    @Published var lastMessageError: String?
    @Published var showMessageError = false
    
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
    
    // MARK: - ✨ Message Send Result (Issue #7 Fix)
    
    enum SendResult {
        case success
        case rateLimited(message: String)
        case blocked(reason: String)
        case invalid(reason: String)
        case error(String)
    }
    
    // MARK: - Actions
    
    /// Sends a message with full validation and sanitization
    /// - Returns: SendResult indicating success or failure reason
    @MainActor
    func sendMessageWithResult(_ text: String, to receiverId: UUID, tradeId: UUID? = nil, imageUrl: String? = nil) async -> SendResult {
        guard let myId = currentUserId else {
            return .error("Not logged in")
        }
        
        // ✨ Issue #7: Skip sanitization for system messages and image placeholders
        let isSystemMessage = text.hasPrefix("ACTION:")
        let isImageMessage = imageUrl != nil
        
        var sanitizedContent = text
        
        if !isSystemMessage && !isImageMessage {
            // ✨ Issue #3: Rate limit check for messages
            let (allowed, rateLimitMsg) = await RateLimiter.canSendMessage()
            if !allowed {
                return .rateLimited(message: rateLimitMsg ?? "Too many messages")
            }
            
            // ✨ Issue #7: Sanitize message content
            let sanitizeResult = MessageSanitizer.sanitize(text)
            
            switch sanitizeResult {
            case .valid(let sanitized):
                sanitizedContent = sanitized
                
            case .tooLong(let maxAllowed):
                return .invalid(reason: "Message too long. Maximum \(maxAllowed) characters allowed.")
                
            case .tooShort:
                return .invalid(reason: "Message too short.")
                
            case .empty:
                return .invalid(reason: "Message cannot be empty.")
                
            case .blocked(let reason):
                return .blocked(reason: reason)
                
            case .invalid(let reason):
                return .invalid(reason: reason)
            }
        }
        
        let newMessage = Message(
            id: UUID(),
            senderId: myId,
            receiverId: receiverId,
            content: sanitizedContent,
            createdAt: Date(),
            imageUrl: imageUrl,
            tradeId: tradeId
        )
        
        // Optimistic UI Update (Snappy!)
        appendMessage(newMessage)
        
        do {
            try await client.from("messages").insert(newMessage).execute()
            return .success
        } catch {
            print("❌ Failed to send message: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// Legacy wrapper - maintains backwards compatibility
    @MainActor
    func sendMessage(_ text: String, to receiverId: UUID, tradeId: UUID? = nil, imageUrl: String? = nil) async {
        let result = await sendMessageWithResult(text, to: receiverId, tradeId: tradeId, imageUrl: imageUrl)
        
        switch result {
        case .success:
            break // All good
        case .rateLimited(let message):
            print("⚠️ Message rate limited: \(message)")
            self.lastMessageError = message
            self.showMessageError = true
        case .blocked(let reason):
            print("🚫 Message blocked: \(reason)")
            self.lastMessageError = reason
            self.showMessageError = true
        case .invalid(let reason):
            print("❌ Message invalid: \(reason)")
            self.lastMessageError = reason
            self.showMessageError = true
        case .error(let msg):
            print("❌ Message error: \(msg)")
            self.lastMessageError = msg
            self.showMessageError = true
        }
    }
    
    @MainActor
    func sendSystemMessage(_ actionType: String, to receiverId: UUID, tradeId: UUID) async {
        // System actions are special codes handled by the UI
        // These bypass sanitization (they're internal codes)
        let content = "ACTION:\(actionType)"
        await sendMessage(content, to: receiverId, tradeId: tradeId)
    }
    
    @MainActor
    func sendImage(data: Data, to receiverId: UUID, tradeId: UUID) async {
        guard let myId = currentUserId else { return }
        
        // ✨ Issue #3: Rate limit check for images (uses message limit)
        let (allowed, rateLimitMsg) = await RateLimiter.canSendMessage()
        if !allowed {
            self.lastMessageError = rateLimitMsg
            self.showMessageError = true
            print("⚠️ Image rate limited: \(rateLimitMsg ?? "unknown")")
            return
        }
        
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
            
            // ✨ Issue #7: Sanitize messages for display (in case old messages weren't sanitized)
            let sanitizedMessages = messages.map { message -> Message in
                var sanitized = message
                if !message.content.hasPrefix("ACTION:") {
                    sanitized = Message(
                        id: message.id,
                        senderId: message.senderId,
                        receiverId: message.receiverId,
                        content: MessageSanitizer.sanitizeForDisplay(message.content),
                        createdAt: message.createdAt,
                        imageUrl: message.imageUrl,
                        tradeId: message.tradeId
                    )
                }
                return sanitized
            }
            
            self.conversations[tradeId] = sanitizedMessages
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
                            var message = try JSONDecoder().decode(Message.self, from: data)
                            
                            // ✨ Issue #7: Sanitize incoming messages for display
                            if !message.content.hasPrefix("ACTION:") {
                                message = Message(
                                    id: message.id,
                                    senderId: message.senderId,
                                    receiverId: message.receiverId,
                                    content: MessageSanitizer.sanitizeForDisplay(message.content),
                                    createdAt: message.createdAt,
                                    imageUrl: message.imageUrl,
                                    tradeId: message.tradeId
                                )
                            }
                            
                            self.appendMessage(message)
                            
                            // Trigger Local Notification if backgrounded
                            if message.senderId != myId {
                                // ✨ Truncate notification body for security
                                let notificationBody = message.content.hasPrefix("ACTION:")
                                    ? "New Update on your trade"
                                    : String(message.content.prefix(100))
                                
                                NotificationManager.shared.sendLocalNotification(
                                    title: "New Message",
                                    body: notificationBody
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
