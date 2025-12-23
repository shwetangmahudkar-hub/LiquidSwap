//
//  AuthView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-23.
//


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
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.white)
                
                // Inputs
                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                }
                
                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
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
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .foregroundStyle(.black)
                            .cornerRadius(12)
                    }
                }
                .disabled(viewModel.isLoading)
                
                // Toggle Mode
                Button(action: { isLoginMode.toggle() }) {
                    Text(isLoginMode ? "New here? Create Account" : "Already have an account? Log In")
                        .font(.subheadline)
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
