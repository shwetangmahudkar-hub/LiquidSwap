import SwiftUI

@main
struct LiquidSwapApp: App { // Or your specific struct name
    
    init() {
        // Simple "Ping" to see if credentials are valid format
        print("⚡️ Supabase Client Initialized: \(SupabaseConfig.supabaseURL)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
