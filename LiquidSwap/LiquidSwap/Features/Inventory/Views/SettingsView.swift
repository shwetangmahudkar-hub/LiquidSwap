import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Dependencies
    @ObservedObject var userManager = UserManager.shared
    
    // UI State
    @State private var showDeleteAlert = false
    @State private var showSignOutAlert = false
    @State private var showClearCacheAlert = false // New Alert State
    @State private var isProcessing = false
    @State private var cacheCleared = false
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // 1. Global Background (DeepGlass)
            LiquidBackground()
            
            VStack(spacing: 0) {
                // 2. Header (Clean - No Close Button per rules)
                HStack {
                    Text("Settings")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Spacer()
                    
                    // Optional: Indicator that this is a "modal" feel
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 4)
                        .padding(.trailing, 20) // Visual balance
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 10)
                
                // 3. Settings Content
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // User Info Card
                        if let user = userManager.currentUser {
                            HStack(spacing: 16) {
                                AsyncImageView(filename: user.avatarUrl)
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.username)
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                    
                                    Text(user.isVerified ? "Verified Trader" : "Standard Account")
                                        .font(.caption)
                                        .foregroundStyle(user.isVerified ? .cyan : .white.opacity(0.6))
                                }
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        
                        // Preferences Section
                        VStack(spacing: 16) {
                            SectionHeader(title: "PREFERENCES")
                            
                            SettingsToggleRow(icon: "moon.fill", title: "Dark Mode", isOn: $isDarkMode)
                            
                            SettingsLinkRow(icon: "bell.fill", title: "Notifications") {
                                // Open Notification Settings logic
                            }
                            
                            SettingsLinkRow(icon: "lock.shield.fill", title: "Privacy & Security") {
                                // Open Privacy logic
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        // Storage & Data (NEW SECTION)
                        VStack(spacing: 16) {
                            SectionHeader(title: "STORAGE & DATA")
                            
                            Button(action: { showClearCacheAlert = true }) {
                                HStack(spacing: 16) {
                                    Image(systemName: cacheCleared ? "checkmark.circle.fill" : "trash.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(cacheCleared ? .green : .orange)
                                        .frame(width: 24)
                                    
                                    Text(cacheCleared ? "Cache Cleared" : "Clear Image Cache")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    if !cacheCleared {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        // Support Section
                        VStack(spacing: 16) {
                            SectionHeader(title: "SUPPORT")
                            
                            SettingsLinkRow(icon: "questionmark.circle.fill", title: "Help Center") { }
                            SettingsLinkRow(icon: "doc.text.fill", title: "Terms of Service") { }
                            
                            HStack {
                                Spacer()
                                Text("Version 1.0.0 (Build 24)")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.3))
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        // Danger Zone
                        Button(action: { showDeleteAlert = true }) {
                            Text("Delete Account")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red.opacity(0.8))
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(20)
                }
            }
            
            // 4. Floating Sign Out Button (Bottom)
            VStack {
                Spacer()
                Button(action: { showSignOutAlert = true }) {
                    ZStack {
                        Capsule()
                            .fill(Color.black.opacity(0.4)) // Darker for contrast
                            .background(.ultraThinMaterial)
                            .frame(height: 56)
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(.headline.bold())
                        }
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            
            // 5. Loading Overlay
            if isProcessing {
                Color.black.opacity(0.6).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .navigationBarHidden(true)
        // ALERTS
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) { performSignOut() }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDeleteAccount() }
        } message: {
            Text("This action will permanently delete your data and inventory. It cannot be undone.")
        }
        // NEW: Clear Cache Alert
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { performClearCache() }
        } message: {
            Text("This will free up space by deleting temporary images. They will be re-downloaded when needed.")
        }
    }
    
    // MARK: - Actions
    
    func performSignOut() {
        isProcessing = true
        Task {
            try? await SupabaseConfig.client.auth.signOut()
            await MainActor.run { isProcessing = false }
        }
    }
    
    func performDeleteAccount() {
        isProcessing = true
        Task {
            try? await SupabaseConfig.client.auth.signOut()
            await MainActor.run { isProcessing = false }
        }
    }
    
    func performClearCache() {
        // ✨ Action: Clear Disk
        DiskManager.clearCache()
        
        // Feedback
        Haptics.shared.playSuccess()
        withAnimation {
            cacheCleared = true
        }
        
        // Reset flag after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { cacheCleared = false }
        }
    }
    
    // MARK: - Subviews
    
    func SectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
    }
}

// MARK: - Reusable Row Components

struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.cyan)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.purple)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.purple)
        }
        .padding(.vertical, 4)
    }
}
