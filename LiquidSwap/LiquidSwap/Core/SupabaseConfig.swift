import Foundation
import Supabase

enum SupabaseConfig {
    // 1. Replace with your ACTUAL project details
    static let supabaseURL = URL(string: "https://feqwpatwevrkyuhuhnmi.supabase.co")!
    static let supabaseKey = "sb_publishable_xlsTKHqQz68d8m1sPLQ6hQ_IqZVE9NR" // <--- MAKE SURE YOUR KEY IS HERE
    
    // 2. The Client
    static let client: SupabaseClient = {
        return SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(
                    // 3. THIS FIXES THE WARNING
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()
}
