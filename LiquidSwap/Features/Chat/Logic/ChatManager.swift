import SwiftUI
import Combine
import Supabase

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    private let client = SupabaseConfig.client
    
    @Published var conversations: [UUID: [Message]] = [:]
    
    // 1. Keep a reference to the active channel
    private var channel: RealtimeChannelV2?
    private var isSetup = false
    
    private init() {}
    
    func setup() async {
        // Double-check: If already setup, stop.
        if isSetup { return }
        isSetup = true
        
        await fetchAllMessages()
        await subscribeToRealtime()
    }
    
    // MARK: - Actions
    
    @MainActor
    func sendMessage(_ text: String, to receiverId: UUID) async {
        guard let myId = UserManager.shared.currentUser?.id else { return }
        
        let newMessage = Message(
            id: UUID(),
            senderId: myId,
            receiverId: receiverId,
            content: text,
            createdAt: Date()
        )
        
        appendMessage(newMessage)
        
        do {
            try await client
                .from("messages")
                .insert(newMessage)
                .execute()
            print("🚀 Message sent!")
        } catch {
            print("❌ Failed to send message: \(error)")
        }
    }
    
    // MARK: - Fetching & Realtime
    
    @MainActor
    func fetchAllMessages() async {
        guard let myId = UserManager.shared.currentUser?.id else { return }
        
        do {
            let messages: [Message] = try await client
                .from("messages")
                .select()
                .or("sender_id.eq.\(myId),receiver_id.eq.\(myId)")
                .order("created_at", ascending: true)
                .execute()
                .value
            
            self.conversations = Dictionary(grouping: messages) { msg in
                return msg.senderId == myId ? msg.receiverId : msg.senderId
            }
            
        } catch {
            print("❌ Error fetching messages: \(error)")
        }
    }
    
    func subscribeToRealtime() async {
        // FIXED: Remove any existing channel before creating a new one
        if let existingChannel = channel {
            await existingChannel.unsubscribe()
        }
        
        // Create the new channel definition
        let newChannel = client.channel("public:messages")
        self.channel = newChannel
        
        // Attach the listener BEFORE subscribing
        let changeStream = newChannel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "messages"
        )
        
        // Subscribe now
        do {
            try await newChannel.subscribeWithError()
            print("✅ Subscribed to realtime messages")
        } catch {
            print("❌ Failed to subscribe to realtime: \(error)")
            return
        }
        
        // Listen for changes
        for await _ in changeStream {
            await fetchAllMessages()
        }
    }
    
    private func appendMessage(_ message: Message) {
        guard let myId = UserManager.shared.currentUser?.id else { return }
        let partnerId = message.senderId == myId ? message.receiverId : message.senderId
        
        if conversations[partnerId] == nil {
            conversations[partnerId] = []
        }
        conversations[partnerId]?.append(message)
    }
}
