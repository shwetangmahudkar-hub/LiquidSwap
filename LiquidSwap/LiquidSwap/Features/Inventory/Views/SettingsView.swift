import SwiftUI
import Supabase

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // Dependencies
    @ObservedObject var userManager = UserManager.shared
    
    // UI State
    @State private var showDeleteAlert = false
    @State private var showSignOutAlert = false
    @State private var isProcessing = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    // MARK: - Adaptive Colors
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5)
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3)
    }
    
    private var buttonBackground: Color {
        colorScheme == .dark ? .white.opacity(0.1) : .black.opacity(0.05)
    }
    
    private var buttonBorder: Color {
        colorScheme == .dark ? .white.opacity(0.2) : .black.opacity(0.1)
    }
    
    var body: some View {
        ZStack {
            // 1. Global Background
            LiquidBackground()
            
            VStack(spacing: 0) {
                // 2. Custom Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(primaryText)
                            .frame(width: 40, height: 40)
                            .background(buttonBackground)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(.headline.bold())
                        .foregroundStyle(primaryText)
                    
                    Spacer()
                    
                    // Balance Spacer
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // 3. Settings Content
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // User Info Card
                        if let user = userManager.currentUser {
                            HStack(spacing: 12) {
                                AsyncImageView(filename: user.avatarUrl)
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(buttonBorder, lineWidth: 2))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.username)
                                        .font(.title3.bold())
                                        .foregroundStyle(primaryText)
                                    
                                    Text(user.isVerified ? "Verified Trader" : "Standard Account")
                                        .font(.caption)
                                        .foregroundStyle(user.isVerified ? .cyan : secondaryText)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        
                        // Preferences Section
                        VStack(spacing: 12) {
                            SectionHeader(title: "PREFERENCES")
                            
                            SettingsToggleRow(icon: "moon.fill", title: "Dark Mode", isOn: $isDarkMode)
                            
                            SettingsLinkRow(icon: "bell.fill", title: "Notifications") {
                                // Open Notification Settings logic or Sheet
                            }
                            
                            SettingsLinkRow(icon: "lock.shield.fill", title: "Privacy & Security") {
                                // Open Privacy logic
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // Support Section
                        VStack(spacing: 12) {
                            SectionHeader(title: "SUPPORT")
                            
                            SettingsLinkRow(icon: "questionmark.circle.fill", title: "Help Center") {
                                // Action
                            }
                            
                            SettingsLinkRow(icon: "doc.text.fill", title: "Terms of Service") {
                                // Action
                            }
                            
                            HStack {
                                Spacer()
                                Text("Version 1.0.0 (Build 24)")
                                    .font(.caption2)
                                    .foregroundStyle(tertiaryText)
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                        // Danger Zone
                        Button(action: { showDeleteAlert = true }) {
                            Text("Delete Account")
                                .font(.subheadline.bold())
                                .foregroundStyle(.red.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                        
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            // 4. Floating Sign Out Button
            VStack {
                Spacer()
                Button(action: { showSignOutAlert = true }) {
                    ZStack {
                        Capsule()
                            .fill(buttonBackground)
                            .frame(height: 50)
                            .overlay(
                                Capsule().stroke(buttonBorder, lineWidth: 1)
                            )
                        
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(primaryText)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
            
            // 5. Loading Overlay
            if isProcessing {
                Color.black.opacity(0.6).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .navigationBarHidden(true)
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
    }
    
    // MARK: - Actions
    
    func performSignOut() {
        isProcessing = true
        Task {
            try? await SupabaseConfig.client.auth.signOut()
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    func performDeleteAccount() {
        isProcessing = true
        Task {
            try? await SupabaseConfig.client.auth.signOut()
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    // MARK: - Subviews
    
    func SectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(secondaryText)
            Spacer()
        }
    }
}

// MARK: - Reusable Row Components

struct SettingsLinkRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    let action: () -> Void
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var tertiaryText: Color {
        colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.3)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.cyan)
                    .frame(width: 22)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(tertiaryText)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsToggleRow: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.purple)
                .frame(width: 22)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(primaryText)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.purple)
        }
        .padding(.vertical, 2)
    }
}
