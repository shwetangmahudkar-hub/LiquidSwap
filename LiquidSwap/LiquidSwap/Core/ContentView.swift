//
//  ContentView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-23.
//


import SwiftUI

struct ContentView: View {
    @StateObject var authVM = AuthViewModel()
    
    var body: some View {
        Group {
            if authVM.isAuthenticated {
                // RESTORED: Go to the Main Tab Bar (Feed + Chat + Profile)
                MainTabView()
                    .environmentObject(authVM) // Pass Auth down so Profile can Sign Out
            } else {
                // If not logged in, show Auth
                AuthView()
                    .environmentObject(authVM)
            }
        }
        .onAppear {
            // Optional: Check if session is expired or valid
            // authVM.checkSession() 
        }
    }
}

#Preview {
    ContentView()
}