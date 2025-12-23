import SwiftUI
import Combine

class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    // NEW: Bot Toggle
    @Published var areBotsEnabled: Bool = true
    
    @Published var conversations: [String: [Message]] = [:] {
        didSet {
            saveChats()
        }
    }
    
    private let saveKey = "saved_chats"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: "saved_chats"),
           let decoded = try? JSONDecoder().decode([String: [Message]].self, from: data) {
            self.conversations = decoded
        }
    }
    
    // --- ACTIONS ---
    
    func sendMessage(_ text: String, to partner: String) {
        let newMessage = Message(content: text, isCurrentUser: true)
        
        if conversations[partner] == nil {
            conversations[partner] = []
        }
        
        conversations[partner]?.append(newMessage)
        
        // NEW: Check if bots are allowed to reply
        if areBotsEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.receiveBotReply(from: partner, context: text)
            }
        }
    }
    
    private func receiveBotReply(from partner: String, context: String) {
        let replyText = generateBotResponse(for: context)
        let reply = Message(content: replyText, isCurrentUser: false)
        
        withAnimation {
            conversations[partner]?.append(reply)
            Haptics.shared.playLight()
        }
    }
    
    private func saveChats() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func generateBotResponse(for input: String) -> String {
        let lowerInput = input.lowercased()
        if lowerInput.contains("available") { return "Yes, it is still available! When can you meet?" }
        else if lowerInput.contains("trade") { return "I'm open to trades. What do you have?" }
        else if lowerInput.contains("where") || lowerInput.contains("location") { return "I'm located downtown, near the park." }
        else if lowerInput.contains("price") || lowerInput.contains("much") { return "I'm mostly looking to swap, but make me an offer." }
        else if lowerInput.contains("hi") || lowerInput.contains("hello") { return "Hey there! Interested in the item?" }
        else { return "Sounds good! Let me know." }
    }
}
