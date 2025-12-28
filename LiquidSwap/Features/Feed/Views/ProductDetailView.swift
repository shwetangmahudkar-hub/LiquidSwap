import SwiftUI

struct ProductDetailView: View {
    let item: TradeItem
    @Environment(\.dismiss) var dismiss
    
    @State private var showReportAlert = false
    @State private var showOfferSheet = false
    @State private var isSendingOffer = false
    @State private var offerAlreadyPending = false
    
    // Local inventory for making offers
    @State private var myInventory: [TradeItem] = []
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Hero Image
                    AsyncImageView(filename: item.imageUrl)
                        .frame(height: 350)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    
                    // 2. Info Section
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Title & Badge Row
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                Text(item.title)
                                    .font(.largeTitle)
                                    .bold()
                                
                                HStack {
                                    Text(item.category)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    // ✨ NEW: Verification Badge
                                    if item.ownerIsVerified == true {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.cyan)
                                            .font(.caption)
                                        
                                        Text("Verified Owner")
                                            .font(.caption)
                                            .foregroundStyle(.cyan)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Condition Tag
                            Text(item.condition)
                                .font(.caption)
                                .bold()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                        
                        Divider()
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            Text(item.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        
                        // Location
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.cyan)
                            
                            Text("\(String(format: "%.1f", item.distance)) km away")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(24)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // 3. Floating Action Bar
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
                        Button(action: {
                            showOfferSheet = true
                        }) {
                            Text("Make an Offer")
                                .font(.headline)
                                .bold()
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
        // Navigation Bar Actions
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
                    .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: { showReportAlert = true }) {
                Image(systemName: "flag.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                    .shadow(radius: 4)
                    .padding()
            }
        }
        .confirmationDialog("Report?", isPresented: $showReportAlert) {
            Button("Inappropriate", role: .destructive) {
                submitReport(reason: "Inappropriate")
            }
            Button("Spam", role: .destructive) {
                submitReport(reason: "Spam")
            }
            Button("Cancel", role: .cancel) { }
        }
        // Offer Sheet
        .sheet(isPresented: $showOfferSheet) {
            NavigationStack {
                List(myInventory) { myItem in
                    Button(action: {
                        sendOffer(with: myItem)
                    }) {
                        HStack {
                            AsyncImageView(filename: myItem.imageUrl)
                                .frame(width: 50, height: 50)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading) {
                                Text(myItem.title).font(.headline)
                                Text(myItem.condition).font(.caption).foregroundStyle(.gray)
                            }
                        }
                    }
                }
                .navigationTitle("Select Item to Trade")
                .toolbar {
                    Button("Cancel") { showOfferSheet = false }
                }
                .onAppear {
                    fetchMyInventory()
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Logic
    
    func fetchMyInventory() {
        Task {
            guard let userId = UserManager.shared.currentUser?.id else { return }
            
            // Simple fetch of my items to populate the picker
            if let items = try? await DatabaseService.shared.fetchUserItems(userId: userId) {
                await MainActor.run {
                    self.myInventory = items
                }
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
                offerAlreadyPending = true
                
                if success {
                    Haptics.shared.playSuccess()
                } else {
                    Haptics.shared.playError()
                }
            }
        }
    }
    
    func submitReport(reason: String) {
        guard let userId = UserManager.shared.currentUser?.id else { return }
        Task {
            try? await DatabaseService.shared.reportItem(itemId: item.id, userId: userId, reason: reason)
            dismiss()
        }
    }
}
