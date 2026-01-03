import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isLoginMode = true // Toggle between Login/Signup
    
    var body: some View {
        ZStack {
            // 1. Background
            LiquidBackground()
            
            // 2. Glass Card
            VStack(spacing: 24) {
                // Header
                Text(isLoginMode ? "Welcome Back" : "Create Account")
                    .appFont(34, weight: .bold) // ✨ Standardized Font
                    .foregroundStyle(.white)
                
                // Inputs
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .appFont(16)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .appFont(16)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .appFont(12)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Main Button
                Button(action: {
                    Task {
                        if isLoginMode {
                            await viewModel.signIn()
                        } else {
                            await viewModel.signUp()
                        }
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text(isLoginMode ? "Log In" : "Sign Up")
                    }
                }
                .buttonStyle(PrimaryButtonStyle()) // ✨ Standardized Button
                .disabled(viewModel.isLoading)
                
                // Toggle Mode
                Button(action: { isLoginMode.toggle() }) {
                    Text(isLoginMode ? "New here? Create Account" : "Already have an account? Log In")
                        .appFont(14)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .padding()
        }
    }
}

#Preview {
    AuthView()
}
