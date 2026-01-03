import SwiftUI

@main
struct LiquidSwapApp: App {
    
    init() {
        print("⚡️ Supabase Client Initialized: \(SupabaseConfig.supabaseURL)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // ✅ FIX: Use the shared instance directly
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}
