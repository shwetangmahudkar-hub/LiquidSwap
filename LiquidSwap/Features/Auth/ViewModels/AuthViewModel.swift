import SwiftUI
import Combine
import Supabase

class AuthViewModel: ObservableObject {
    @Published var session: Session?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var email = ""
    @Published var password = ""
    
    // Use the shared client from SupabaseConfig
    private let client = SupabaseConfig.client
    
    init() {
        setupAuthListener()
    }
    
    func setupAuthListener() {
        Task {
            for await state in client.auth.authStateChanges {
                await MainActor.run {
                    self.session = state.session
                    self.isAuthenticated = (state.session != nil)
                    print("🔄 Auth State Changed: \(self.isAuthenticated ? "Logged In" : "Logged Out")")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func signIn() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            print("✅ Login Successful: \(session.user.email ?? "No Email")")
            await MainActor.run { self.isLoading = false }
        } catch {
            print("🟥 LOGIN ERROR: \(error.localizedDescription)")
            
            await MainActor.run {
                self.errorMessage = "Login failed. Please check your credentials."
                self.isLoading = false
            }
        }
    }
    
    func signUp() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let session = try await client.auth.signUp(email: email, password: password)
            print("✅ Sign Up Successful: \(session.user.email ?? "No Email")")
            await MainActor.run { self.isLoading = false }
        } catch {
            print("🟥 SIGN UP ERROR: \(error)")
            
            await MainActor.run {
                // Better Error Handling
                let errorString = String(describing: error)
                if errorString.contains("user_already_exists") || error.localizedDescription.contains("registered") {
                    self.errorMessage = "Account already exists. Please switch to Log In."
                } else {
                    self.errorMessage = "Sign up failed: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            print("👋 Signed Out")
            await MainActor.run {
                self.isAuthenticated = false
                self.session = nil
            }
        } catch {
            print("🟥 Sign Out Error: \(error)")
        }
    }
}
