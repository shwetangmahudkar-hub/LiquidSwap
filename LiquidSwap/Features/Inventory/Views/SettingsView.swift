import SwiftUI
import Supabase

struct ProfileSettingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var showSettings: Bool
    
    @State private var showResetAlert = false
    
    // ✅ FIXED: Missing state variable added
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
                
                // --- SECTION 2: TEST TOOLS ---
                Section("Developer Tools") {
                    // This button lets you test the rating UI
                    Button("Test Rating System (Rate Myself)") {
                        showRatingSheet = true
                    }
                }
                
                // --- SECTION 3: STORAGE ---
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
            // Alert for Clearing Cache
            .alert("Clear Cache?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    DiskManager.clearAllData()
                    showSettings = false
                }
            } message: {
                Text("This will delete all local temporary files and images. Your cloud data (items, messages) will remain safe.")
            }
            // ✅ FIXED: Sheet modifier for rating
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
