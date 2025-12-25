import Foundation
import Supabase

enum SupabaseConfig {
    // 1. Replace with your ACTUAL project details
    static let supabaseURL = URL(string: "https://hzkfssvataegwuqfxruo.supabase.co")!
    static let supabaseKey = "sb_publishable_qnQweyLUOrhFJrK41ejWTQ_CAZ_N-mR" // <--- MAKE SURE YOUR KEY IS HERE
    
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
