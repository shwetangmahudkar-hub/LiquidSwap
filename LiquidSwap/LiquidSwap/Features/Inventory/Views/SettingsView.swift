import SwiftUI
import Supabase

// RENAMED STRUCT: ProfileSettingsView
struct ProfileSettingsView: View {
    // 1. Access the Auth Logic
    @EnvironmentObject var authVM: AuthViewModel
    
    // 2. The Binding variable (The connector)
    @Binding var showSettings: Bool
    
    @State private var showResetAlert = false
    
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
                            showSettings = false // Close settings to show login
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
                
                // --- SECTION 2: SIMULATION CONTROLS ---
                Section("Simulation & Debug") {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Text("Factory Reset (Nuke Data)")
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
            // Alert for Nuking Data
            .alert("Reset Simulation?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Nuke It", role: .destructive) {
                    DiskManager.clearAllData()
                    showSettings = false
                }
            } message: {
                Text("This will delete all local cached items and chat history. This action cannot be undone.")
            }
        }
    }
}

#Preview {
    ProfileSettingsView(showSettings: .constant(true))
        .environmentObject(AuthViewModel())
}
