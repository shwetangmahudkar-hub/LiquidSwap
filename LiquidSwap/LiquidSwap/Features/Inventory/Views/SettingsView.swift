//
//  SettingsView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-22.
//


import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var chatManager = ChatManager.shared
    
    // Alert State
    @State private var showResetAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    // Section 1: Simulation Controls
                    Section(header: Text("Simulation Control")) {
                        Toggle("Enable AI Bot Replies", isOn: $chatManager.areBotsEnabled)
                            .tint(.cyan)
                    }
                    
                    // Section 2: App Info
                    Section(header: Text("Storage & Data")) {
                        HStack {
                            Text("Cached Images")
                            Spacer()
                            // Mock value for MVP
                            Text("12.4 MB")
                                .foregroundStyle(.gray)
                        }
                        
                        HStack {
                            Text("Total Trades")
                            Spacer()
                            Text("\(UserManager.shared.tradeCount)")
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    // Section 3: Danger Zone
                    Section(header: Text("Danger Zone").foregroundStyle(.red)) {
                        Button(action: { showResetAlert = true }) {
                            HStack {
                                Text("Reset All Data")
                                    .bold()
                                    .foregroundStyle(.red)
                                Spacer()
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    // Footer
                    Section {
                        HStack {
                            Spacer()
                            Text("Liquid Swap v1.0 (MVP)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden) // Glass look
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.cyan)
                }
            }
            // Reset Confirmation Alert
            .alert("Factory Reset", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset Everything", role: .destructive) {
                    // Trigger the Nuke
                    UserManager.shared.resetAllData()
                    // Force app close or just dismiss (Onboarding will appear instantly because isFirstLaunch is true)
                    dismiss() 
                }
            } message: {
                Text("This will delete your profile, inventory, trade history, and all chat messages. This cannot be undone.")
            }
        }
    }
}

#Preview {
    SettingsView()
}