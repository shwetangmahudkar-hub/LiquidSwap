//
//  TradesView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-24.
//


import SwiftUI

struct TradesView: View {
    @StateObject var tradeManager = TradeManager.shared
    @State private var selectedTab = "Interested"
    let tabs = ["Interested", "Offers", "Messages"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        HStack {
                            Text("Trades & Chats")
                                .font(.title).bold()
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        
                        // Custom Segmented Control
                        HStack(spacing: 0) {
                            ForEach(tabs, id: \.self) { tab in
                                Button(action: { withAnimation { selectedTab = tab } }) {
                                    VStack(spacing: 8) {
                                        Text(tab)
                                            .font(.subheadline).bold()
                                            .foregroundStyle(selectedTab == tab ? .cyan : .gray)
                                        
                                        Rectangle()
                                            .fill(selectedTab == tab ? Color.cyan : Color.clear)
                                            .frame(height: 2)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    // Content
                    ScrollView {
                        if selectedTab == "Interested" {
                            InterestedListView()
                        } else if selectedTab == "Offers" {
                            IncomingOffersView()
                        } else {
                            // Reusing the old chat list logic here
                            ChatListSubView()
                        }
                    }
                    .refreshable {
                        await tradeManager.loadTradesData()
                        await ChatManager.shared.fetchAllMessages()
                    }
                }
            }
            .onAppear {
                Task { await tradeManager.loadTradesData() }
            }
        }
    }
}

// --- SUBVIEWS ---

// 1. INTERESTED LIST (Items I Liked)
struct InterestedListView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    @State private var selectedItemToOffer: TradeItem?
    
    var body: some View {
        LazyVStack(spacing: 16) {
            if tradeManager.interestedItems.isEmpty {
                EmptyState(icon: "heart.slash", text: "No interested items yet.")
            } else {
                ForEach(tradeManager.interestedItems) { item in
                    GlassCard {
                        HStack(spacing: 16) {
                            AsyncImageView(filename: item.imageUrl)
                                .frame(width: 80, height: 80)
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline).foregroundStyle(.white)
                                Text(item.category).font(.caption).foregroundStyle(.gray)
                                Button(action: {
                                    selectedItemToOffer = item
                                }) {
                                    Text("Make Offer")
                                        .font(.caption).bold()
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.cyan)
                                        .foregroundStyle(.black)
                                        .cornerRadius(8)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $selectedItemToOffer) { item in
            MakeOfferView(wantedItem: item)
        }
    }
}

// 2. INCOMING OFFERS (People want my stuff)
struct IncomingOffersView: View {
    @ObservedObject var tradeManager = TradeManager.shared
    
    var body: some View {
        LazyVStack(spacing: 16) {
            if tradeManager.incomingOffers.isEmpty {
                EmptyState(icon: "tray", text: "No pending offers.")
            } else {
                ForEach(tradeManager.incomingOffers) { offer in
                    VStack(spacing: 12) {
                        // The Trade Visual
                        HStack {
                            // Their Item (Offered)
                            VStack {
                                Text("They Offer").font(.caption).foregroundStyle(.gray)
                                AsyncImageView(filename: offer.offeredItem?.imageUrl)
                                    .frame(width: 60, height: 60).cornerRadius(8)
                                Text(offer.offeredItem?.title ?? "Unknown").font(.caption2).foregroundStyle(.white)
                            }
                            
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundStyle(.cyan)
                            
                            // My Item (Wanted)
                            VStack {
                                Text("For Your").font(.caption).foregroundStyle(.gray)
                                AsyncImageView(filename: offer.wantedItem?.imageUrl)
                                    .frame(width: 60, height: 60).cornerRadius(8)
                                Text(offer.wantedItem?.title ?? "Unknown").font(.caption2).foregroundStyle(.white)
                            }
                        }
                        
                        // Actions
                        HStack(spacing: 20) {
                            Button(action: { Task { await tradeManager.respondToOffer(offer, accept: false) } }) {
                                Text("Decline").font(.caption).bold().foregroundStyle(.red)
                                    .padding(.vertical, 8).padding(.horizontal, 20)
                                    .background(Color.red.opacity(0.1)).cornerRadius(8)
                            }
                            
                            Button(action: { Task { await tradeManager.respondToOffer(offer, accept: true) } }) {
                                Text("Accept").font(.caption).bold().foregroundStyle(.green)
                                    .padding(.vertical, 8).padding(.horizontal, 20)
                                    .background(Color.green.opacity(0.1)).cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1)))
                }
            }
        }
        .padding()
    }
}

// 3. CHAT LIST (Reused Logic)
struct ChatListSubView: View {
    @ObservedObject var chatManager = ChatManager.shared
    
    var body: some View {
        LazyVStack(spacing: 0) {
            if chatManager.conversations.isEmpty {
                EmptyState(icon: "message", text: "No active chats.")
            } else {
                ForEach(Array(chatManager.conversations.keys), id: \.self) { partnerId in
                    NavigationLink(destination: ChatRoomView(partnerId: partnerId)) {
                        GlassChatRow(partnerId: partnerId)
                    }
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
    }
}

struct EmptyState: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(.gray)
            Text(text).foregroundStyle(.gray)
        }
        .padding(.top, 40)
    }
}