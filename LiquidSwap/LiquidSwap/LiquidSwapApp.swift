import SwiftUI

@main
struct LiquidSwapApp: App {
    
    // ✅ Read the dark mode preference from UserDefaults
    @AppStorage("isDarkMode") private var isDarkMode = true
    
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
                // ✅ Apply the color scheme based on user preference
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
