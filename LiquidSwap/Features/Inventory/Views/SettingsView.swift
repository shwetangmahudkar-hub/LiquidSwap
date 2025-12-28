import SwiftUI
import Supabase

struct ProfileSettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    // ✨ NEW: Access UserManager for blocked list
    @ObservedObject var userManager = UserManager.shared
    
    @Binding var showSettings: Bool
    
    @State private var showResetAlert = false
    @State private var showRatingSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // --- SECTION 1: ACCOUNT ---
                Section("Account") {
                    if let email = authVM.session?.user.email {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(.gray)
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await authVM.signOut()
                            showSettings = false
                        }
                    }) {
                        HStack {
                            Text("Sign Out")
                                .foregroundStyle(.red)
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                // --- SECTION 2: SAFETY ---
                // ✨ NEW: Manage Blocked Users
                Section("Privacy & Safety") {
                    NavigationLink {
                        BlockedUsersList()
                    } label: {
                        HStack {
                            Text("Blocked Users")
                            Spacer()
                            Text("\(userManager.blockedUserIds.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // --- SECTION 3: TEST TOOLS ---
                Section("Developer Tools") {
                    Button("Test Rating System (Rate Myself)") {
                        showRatingSheet = true
                    }
                }
                
                // --- SECTION 4: STORAGE ---
                Section("Storage & Debug") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Text("Clear Local Cache")
                            Spacer()
                            Image(systemName: "trash")
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Cloud Beta)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showSettings = false
                    }
                }
            }
            .alert("Clear Cache?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    DiskManager.clearAllData()
                    showSettings = false
                }
            } message: {
                Text("This will delete all local temporary files and images. Your cloud data (items, messages) will remain safe.")
            }
            .sheet(isPresented: $showRatingSheet) {
                if let myId = UserManager.shared.currentUser?.id {
                    RateUserView(targetUserId: myId, targetUsername: "Myself")
                } else {
                    Text("Please log in first.")
                }
            }
        }
    }
}

// ✨ NEW: Subview for managing blocks
struct BlockedUsersList: View {
    @ObservedObject var userManager = UserManager.shared
    
    var body: some View {
        List {
            if userManager.blockedUserIds.isEmpty {
                Text("You haven't blocked anyone.")
                    .foregroundStyle(.gray)
            } else {
                ForEach(userManager.blockedUserIds, id: \.self) { userId in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("User ID")
                                .font(.caption).foregroundStyle(.gray)
                            Text(userId.uuidString.prefix(8) + "...")
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        Spacer()
                        
                        Button("Unblock") {
                            Task {
                                await userManager.unblockUser(userId: userId)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("Blocked Users")
    }
}
