//
//  ErrorHandling_QuickReference.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-24.
//

import SwiftUI

/*
 
 ERROR HANDLING QUICK REFERENCE
 ===============================
 
 Copy-paste these patterns into your views!
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 1: Basic Error Alert                                 ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct MyView: View {
     @StateObject private var tradeManager = TradeManager.shared
     
     var body: some View {
         // Your view content
         Text("Hello")
             .errorAlert(
                 isPresented: $tradeManager.showError,
                 message: tradeManager.errorMessage,
                 onDismiss: {
                     tradeManager.clearError()
                 }
             )
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 2: Action Button with Success/Error Handling         ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct SendOfferButton: View {
     @StateObject private var tradeManager = TradeManager.shared
     let wantedItem: TradeItem
     let myItem: TradeItem
     
     @State private var isProcessing = false
     @State private var showSuccess = false
     
     var body: some View {
         Button {
             handleSendOffer()
         } label: {
             if isProcessing {
                 ProgressView()
             } else {
                 Label("Send Offer", systemImage: "paperplane.fill")
             }
         }
         .disabled(isProcessing)
         .alert("Success! 🎉", isPresented: $showSuccess) {
             Button("OK") { }
         } message: {
             Text("Your offer has been sent!")
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: { tradeManager.clearError() }
         )
     }
     
     private func handleSendOffer() {
         Task {
             isProcessing = true
             let success = await tradeManager.sendOffer(
                 wantedItem: wantedItem,
                 myItem: myItem
             )
             isProcessing = false
             
             if success {
                 showSuccess = true
             }
             // Error is automatically shown by TradeManager
         }
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 3: List with Loading & Refresh                       ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct TradesList: View {
     @StateObject private var tradeManager = TradeManager.shared
     
     var body: some View {
         List(tradeManager.incomingOffers) { offer in
             OfferRow(offer: offer)
         }
         .overlay {
             if tradeManager.isLoading {
                 ProgressView("Loading...")
             }
         }
         .refreshable {
             await tradeManager.loadTradesData()
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: { tradeManager.clearError() }
         )
         .task {
             await tradeManager.loadTradesData()
         }
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 4: Toggle State (Like/Unlike)                        ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct InterestButton: View {
     @StateObject private var tradeManager = TradeManager.shared
     let item: TradeItem
     
     @State private var isInterested = false
     @State private var isProcessing = false
     
     var body: some View {
         Button {
             toggleInterest()
         } label: {
             HStack {
                 if isProcessing {
                     ProgressView()
                         .controlSize(.small)
                 }
                 Image(systemName: isInterested ? "heart.fill" : "heart")
                     .foregroundColor(isInterested ? .red : .gray)
             }
         }
         .disabled(isProcessing)
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: { tradeManager.clearError() }
         )
         .onAppear {
             checkIfInterested()
         }
     }
     
     private func toggleInterest() {
         Task {
             isProcessing = true
             
             let success: Bool
             if isInterested {
                 success = await tradeManager.removeInterest(item: item)
             } else {
                 success = await tradeManager.markAsInterested(item: item)
             }
             
             if success {
                 isInterested.toggle()
             }
             
             isProcessing = false
         }
     }
     
     private func checkIfInterested() {
         isInterested = tradeManager.interestedItems.contains { $0.id == item.id }
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 5: Accept/Reject with Confirmation                   ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct OfferActions: View {
     @StateObject private var tradeManager = TradeManager.shared
     let offer: TradeOffer
     
     @State private var showAcceptConfirm = false
     @State private var showRejectConfirm = false
     @State private var isProcessing = false
     
     var body: some View {
         HStack(spacing: 12) {
             Button("Reject") {
                 showRejectConfirm = true
             }
             .buttonStyle(.bordered)
             .tint(.red)
             
             Button("Accept") {
                 showAcceptConfirm = true
             }
             .buttonStyle(.borderedProminent)
             .tint(.green)
         }
         .disabled(isProcessing)
         .confirmationDialog("Accept Offer?", isPresented: $showAcceptConfirm) {
             Button("Accept Trade") {
                 respondToOffer(accept: true)
             }
             Button("Cancel", role: .cancel) { }
         } message: {
             Text("This will start a chat with the sender.")
         }
         .confirmationDialog("Reject Offer?", isPresented: $showRejectConfirm) {
             Button("Reject", role: .destructive) {
                 respondToOffer(accept: false)
             }
             Button("Cancel", role: .cancel) { }
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: { tradeManager.clearError() }
         )
     }
     
     private func respondToOffer(accept: Bool) {
         Task {
             isProcessing = true
             let success = await tradeManager.respondToOffer(offer, accept: accept)
             isProcessing = false
             
             if success && accept {
                 // Navigate to chat or show success
             }
         }
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 6: Retry on Error                                    ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct TradesViewWithRetry: View {
     @StateObject private var tradeManager = TradeManager.shared
     
     @State private var showRetryOption = false
     @State private var lastErrorMessage = ""
     
     var body: some View {
         List {
             // Your content
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: {
                 lastErrorMessage = tradeManager.errorMessage ?? ""
                 tradeManager.clearError()
                 
                 // Show retry option after dismissing error
                 if !lastErrorMessage.isEmpty {
                     showRetryOption = true
                 }
             }
         )
         .confirmationDialog("Retry?", isPresented: $showRetryOption) {
             Button("Retry") {
                 Task {
                     await tradeManager.loadTradesData()
                 }
             }
             Button("Cancel", role: .cancel) { }
         } message: {
             Text("Operation failed. Would you like to try again?")
         }
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 7: Empty State with Error Recovery                   ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct EmptyStateView: View {
     @StateObject private var tradeManager = TradeManager.shared
     
     var body: some View {
         VStack(spacing: 16) {
             if tradeManager.isLoading {
                 ProgressView()
                 Text("Loading...")
                     .foregroundColor(.secondary)
             } else if tradeManager.incomingOffers.isEmpty {
                 Image(systemName: "tray")
                     .font(.system(size: 60))
                     .foregroundColor(.secondary)
                 
                 Text("No Offers Yet")
                     .font(.headline)
                 
                 Text("When someone sends you a trade offer, it will appear here.")
                     .font(.subheadline)
                     .foregroundColor(.secondary)
                     .multilineTextAlignment(.center)
                     .padding(.horizontal)
                 
                 Button {
                     Task {
                         await tradeManager.loadTradesData()
                     }
                 } label: {
                     Label("Refresh", systemImage: "arrow.clockwise")
                 }
                 .buttonStyle(.bordered)
             }
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: { tradeManager.clearError() }
         )
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  PATTERN 8: Multiple Managers (Trade + User + Chat)           ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 struct ComplexView: View {
     @StateObject private var tradeManager = TradeManager.shared
     @StateObject private var userManager = UserManager.shared
     @StateObject private var chatManager = ChatManager.shared
     
     // Combine all error states
     private var hasError: Binding<Bool> {
         Binding(
             get: {
                 tradeManager.showError ||
                 userManager.isLoading // Assuming UserManager has error handling too
             },
             set: { _ in }
         )
     }
     
     private var errorMessage: String {
         if tradeManager.showError {
             return tradeManager.errorMessage ?? "Trade error"
         }
         // Add other managers' errors
         return "An error occurred"
     }
     
     var body: some View {
         VStack {
             // Your content
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: { tradeManager.clearError() }
         )
         // Add alerts for other managers as needed
     }
 }
 
 
 ╔═══════════════════════════════════════════════════════════════╗
 ║  TIPS & BEST PRACTICES                                        ║
 ╚═══════════════════════════════════════════════════════════════╝
 
 1. Always call clearError() in onDismiss
 2. Show ProgressView during async operations
 3. Disable buttons while processing
 4. Use optimistic updates for better UX
 5. Provide manual retry options (pull-to-refresh)
 6. Test with airplane mode enabled
 7. Use confirmationDialog for destructive actions
 8. Log errors for debugging (already done in handleError)
 
 */
