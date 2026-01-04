import SwiftUI

@main
struct LiquidSwapApp: App {
    // ✨ 1. Create the ModalManager instance
    @StateObject private var modalManager = ModalManager()
    
    init() {
        // Keep your original Supabase init
        print("⚡️ Supabase Client Initialized: \(SupabaseConfig.supabaseURL)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // ✨ 2. Inject ModalManager into the environment
                .environmentObject(modalManager)
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}
