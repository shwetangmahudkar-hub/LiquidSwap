import Foundation
import Supabase

enum SupabaseConfig {
    // 1. Replace with your ACTUAL project details
    static let supabaseURL = URL(string: "https://hzkfssvataegwuqfxruo.supabase.co")!
    static let supabaseKey = "sb_publishable_qnQweyLUOrhFJrK41ejWTQ_CAZ_N-mR" // <--- MAKE SURE YOUR KEY IS HERE
    
    // 2. The Client
    static let client: SupabaseClient = {
        // 🛠️ FIX: Create custom coders to handle ISO8601 Dates correctly
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                // ✨ Apply the custom coders here
                db: .init(encoder: encoder, decoder: decoder),
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()
}
