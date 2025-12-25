//
//  TradeManager+Examples.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-24.
//

import SwiftUI

/*
 
 EXAMPLE 1: Using Error Alerts in a View
 ========================================
 
 struct InterestedItemsView: View {
     @StateObject private var tradeManager = TradeManager.shared
     
     var body: some View {
         List(tradeManager.interestedItems) { item in
             ItemRow(item: item)
         }
         .navigationTitle("Interested Items")
         .overlay {
             if tradeManager.isLoading {
                 ProgressView()
             }
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: {
                 tradeManager.clearError()
             }
         )
         .task {
             await tradeManager.loadTradesData()
         }
     }
 }
 
 
 EXAMPLE 2: Handling Action Responses
 =====================================
 
 struct SendOfferButton: View {
     @StateObject private var tradeManager = TradeManager.shared
     let wantedItem: TradeItem
     let myItem: TradeItem
     
     @State private var isProcessing = false
     @State private var showSuccess = false
     
     var body: some View {
         Button {
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
         } label: {
             if isProcessing {
                 ProgressView()
             } else {
                 Text("Send Offer")
             }
         }
         .disabled(isProcessing)
         .alert("Offer Sent! 🎉", isPresented: $showSuccess) {
             Button("OK") { }
         } message: {
             Text("Your trade offer has been sent. You'll be notified when they respond.")
         }
     }
 }
 
 
 EXAMPLE 3: Responding to Offers
 ================================
 
 struct OfferCardView: View {
     @StateObject private var tradeManager = TradeManager.shared
     let offer: TradeOffer
     
     @State private var isProcessing = false
     
     var body: some View {
         VStack(alignment: .leading, spacing: 12) {
             Text("Trade Offer")
                 .font(.headline)
             
             HStack {
                 // Their item
                 VStack {
                     AsyncImage(url: URL(string: offer.offeredItem?.imageUrl ?? "")) { image in
                         image.resizable().scaledToFit()
                     } placeholder: {
                         Color.gray
                     }
                     .frame(width: 80, height: 80)
                     .cornerRadius(8)
                     
                     Text(offer.offeredItem?.title ?? "Unknown")
                         .font(.caption)
                 }
                 
                 Image(systemName: "arrow.left.arrow.right")
                     .foregroundColor(.blue)
                 
                 // Your item
                 VStack {
                     AsyncImage(url: URL(string: offer.wantedItem?.imageUrl ?? "")) { image in
                         image.resizable().scaledToFit()
                     } placeholder: {
                         Color.gray
                     }
                     .frame(width: 80, height: 80)
                     .cornerRadius(8)
                     
                     Text(offer.wantedItem?.title ?? "Unknown")
                         .font(.caption)
                 }
             }
             
             HStack(spacing: 12) {
                 Button("Reject") {
                     respondToOffer(accept: false)
                 }
                 .buttonStyle(.bordered)
                 .tint(.red)
                 
                 Button("Accept") {
                     respondToOffer(accept: true)
                 }
                 .buttonStyle(.borderedProminent)
                 .tint(.green)
             }
             .disabled(isProcessing)
         }
         .padding()
         .background(Color(.systemBackground))
         .cornerRadius(12)
         .shadow(radius: 2)
     }
     
     private func respondToOffer(accept: Bool) {
         Task {
             isProcessing = true
             let success = await tradeManager.respondToOffer(offer, accept: accept)
             isProcessing = false
             
             if success && accept {
                 // Navigate to chat or show success message
             }
         }
     }
 }
 
 
 EXAMPLE 4: Mark as Interested with Feedback
 ============================================
 
 struct ItemDetailView: View {
     @StateObject private var tradeManager = TradeManager.shared
     let item: TradeItem
     
     @State private var isInterested = false
     @State private var isProcessing = false
     
     var body: some View {
         VStack {
             // Item details...
             
             Button {
                 Task {
                     isProcessing = true
                     
                     if isInterested {
                         let success = await tradeManager.removeInterest(item: item)
                         if success {
                             isInterested = false
                         }
                     } else {
                         let success = await tradeManager.markAsInterested(item: item)
                         if success {
                             isInterested = true
                         }
                     }
                     
                     isProcessing = false
                 }
             } label: {
                 HStack {
                     if isProcessing {
                         ProgressView()
                     }
                     Image(systemName: isInterested ? "heart.fill" : "heart")
                     Text(isInterested ? "Interested" : "Mark as Interested")
                 }
             }
             .buttonStyle(.borderedProminent)
             .disabled(isProcessing)
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: {
                 tradeManager.clearError()
             }
         )
         .onAppear {
             // Check if already interested
             isInterested = tradeManager.interestedItems.contains { $0.id == item.id }
         }
     }
 }
 
 
 EXAMPLE 5: Retry Failed Operations
 ===================================
 
 struct TradesListView: View {
     @StateObject private var tradeManager = TradeManager.shared
     
     @State private var showRetryAlert = false
     @State private var lastError: String?
     
     var body: some View {
         List {
             Section("Incoming Offers") {
                 if tradeManager.incomingOffers.isEmpty {
                     Text("No pending offers")
                         .foregroundColor(.secondary)
                 } else {
                     ForEach(tradeManager.incomingOffers) { offer in
                         OfferCardView(offer: offer)
                     }
                 }
             }
             
             Section("Items You're Interested In") {
                 if tradeManager.interestedItems.isEmpty {
                     Text("No items yet")
                         .foregroundColor(.secondary)
                 } else {
                     ForEach(tradeManager.interestedItems) { item in
                         ItemRow(item: item)
                     }
                 }
             }
         }
         .refreshable {
             await tradeManager.loadTradesData()
         }
         .overlay {
             if tradeManager.isLoading {
                 ProgressView()
             }
         }
         .errorAlert(
             isPresented: $tradeManager.showError,
             message: tradeManager.errorMessage,
             onDismiss: {
                 lastError = tradeManager.errorMessage
                 tradeManager.clearError()
                 showRetryAlert = true
             }
         )
         .alert("Retry?", isPresented: $showRetryAlert) {
             Button("Retry") {
                 Task {
                     await tradeManager.loadTradesData()
                 }
             }
             Button("Cancel", role: .cancel) { }
         } message: {
             Text(lastError ?? "Operation failed. Would you like to try again?")
         }
         .task {
             await tradeManager.loadTradesData()
         }
     }
 }
 
 */

// Placeholder structs for examples
fileprivate struct ItemRow: View {
    let item: TradeItem
    var body: some View {
        Text(item.title)
    }
}
