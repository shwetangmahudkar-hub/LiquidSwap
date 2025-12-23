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
    
    // FIXED: Use the shared client from SupabaseConfig (which has the fix applied)
    // instead of creating a new one.
    private let client = SupabaseConfig.client
    
    init() {
        setupAuthListener()
    }
    
    func setupAuthListener() {
        Task {
            for await state in client.auth.authStateChanges {
                DispatchQueue.main.async {
                    self.session = state.session
                    self.isAuthenticated = (state.session != nil)
                    print("🔄 Auth State Changed: \(self.isAuthenticated ? "Logged In" : "Logged Out")")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func signIn() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            print("✅ Login Successful: \(session.user.email ?? "No Email")")
        } catch {
            print("❌ LOGIN ERROR: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signUp() async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let session = try await client.auth.signUp(email: email, password: password)
            print("✅ Sign Up Successful: \(session.user.email ?? "No Email")")
        } catch {
            print("❌ SIGN UP ERROR: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            print("👋 Signed Out")
        } catch {
            print("❌ Sign Out Error: \(error)")
        }
    }
}
