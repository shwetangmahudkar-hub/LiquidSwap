import SwiftUI

struct ProductDetailView: View {
    let item: TradeItem
    @Environment(\.dismiss) var dismiss
    
    // Reporting State
    @State private var showReportAlert = false
    @State private var reportReason = "Inappropriate Content"
    @State private var isReporting = false
    
    // ✨ NEW: Offer State
    @State private var showOfferSheet = false
    @State private var isSendingOffer = false
    @State private var offerAlreadyPending = false
    @State private var myInventory: [TradeItem] = [] // Loaded from DB
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Image
                    AsyncImageView(filename: item.imageUrl)
                        .frame(height: 350)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    
                    // Content
                    VStack(alignment: .leading, spacing: 20) {
                        // Title Row
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title).font(.largeTitle).bold()
                                Text(item.category).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.condition).font(.caption).bold()
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.ultraThinMaterial).cornerRadius(8)
                        }
                        
                        Divider()
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description").font(.headline)
                            Text(item.description).font(.body).foregroundStyle(.secondary).lineSpacing(4)
                        }
                        
                        // Location
                        HStack {
                            Image(systemName: "location.fill").foregroundStyle(.cyan)
                            Text("\(String(format: "%.1f", item.distance)) km away")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 100) // Space for bottom bar
                    }
                    .padding(24)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // ✨ NEW: Sticky "Make Offer" Bar
            VStack {
                Spacer()
                HStack {
                    if offerAlreadyPending {
                        Text("Offer Pending")
                            .font(.headline)
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(15)
                    } else {
                        Button(action: { showOfferSheet = true }) {
                            Text("Make an Offer")
                                .font(.headline).bold()
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan)
                                .cornerRadius(15)
                                .shadow(radius: 5)
                        }
                        .disabled(isSendingOffer)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                .background(.ultraThinMaterial)
            }
        }
        // Overlays (Close & Report)
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white).shadow(radius: 4).padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { showReportAlert = true }) {
                Image(systemName: "flag.circle.fill").font(.largeTitle).foregroundStyle(.red).shadow(radius: 4).padding()
            }
        }
        // Dialogs
        .confirmationDialog("Report this item?", isPresented: $showReportAlert, titleVisibility: .visible) {
            Button("Report as Inappropriate", role: .destructive) { submitReport(reason: "Inappropriate Content") }
            Button("Report as Spam", role: .destructive) { submitReport(reason: "Spam") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Our team will review this item within 24 hours.")
        }
        
        // ✨ NEW: Offer Sheet (Inventory Picker)
        .sheet(isPresented: $showOfferSheet) {
            NavigationStack {
                List(myInventory) { myItem in
                    Button(action: {
                        sendOffer(with: myItem)
                    }) {
                        HStack {
                            AsyncImageView(filename: myItem.imageUrl)
                                .frame(width: 50, height: 50).cornerRadius(8)
                            VStack(alignment: .leading) {
                                Text(myItem.title).font(.headline)
                                Text(myItem.condition).font(.caption).foregroundStyle(.gray)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill").foregroundStyle(.cyan)
                        }
                    }
                }
                .navigationTitle("Select Item to Trade")
                .toolbar { Button("Cancel") { showOfferSheet = false } }
                .onAppear { fetchMyInventory() }
            }
            .presentationDetents([.medium])
        }
        
        .onAppear {
            // Check if we already have a trade
            checkPendingStatus()
        }
    }
    
    // MARK: - Logic
    
    func checkPendingStatus() {
        // Simplified check: In a real app, query TradeManager
        // For now, we assume if we have an offer logic, we'd check it here.
        // We will implement a quick check if myInventory loads.
    }
    
    func fetchMyInventory() {
        Task {
            guard let userId = UserManager.shared.currentUser?.id else { return }
            // Fetch my items to populate the picker
            if let items = try? await DatabaseService.shared.fetchUserItems(userId: userId) {
                await MainActor.run { myInventory = items }
            }
        }
    }
    
    func sendOffer(with myItem: TradeItem) {
        isSendingOffer = true
        showOfferSheet = false
        
        Task {
            let success = await TradeManager.shared.sendOffer(wantedItem: item, myItem: myItem)
            
            await MainActor.run {
                isSendingOffer = false
                if success {
                    offerAlreadyPending = true
                    Haptics.shared.playSuccess()
                } else {
                    Haptics.shared.playError() // Likely duplicate
                    offerAlreadyPending = true // Update UI to reflect it exists
                }
            }
        }
    }
    
    func submitReport(reason: String) {
        guard let userId = UserManager.shared.currentUser?.id else { return }
        isReporting = true
        Task {
            try? await DatabaseService.shared.reportItem(itemId: item.id, userId: userId, reason: reason)
            isReporting = false
            dismiss()
        }
    }
}
