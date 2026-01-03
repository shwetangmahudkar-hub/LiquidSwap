import SwiftUI
import MapKit

struct ProductDetailView: View {
    let item: TradeItem
    @Environment(\.dismiss) var dismiss
    
    // Dependencies
    @ObservedObject var userManager = UserManager.shared
    
    // UI State
    @State private var showReportActionSheet = false
    @State private var showReportConfirmation = false
    
    @State private var showOfferSheet = false
    @State private var showShareSheet = false
    @State private var showSellerProfile = false
    @State private var showChatAlert = false
    
    // Data State
    @State private var offerAlreadyPending = false
    @State private var ownerProfile: UserProfile?
    @State private var ownerRating: Double = 0.0
    @State private var isLoadingOwner = true
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. Global Background
            LiquidBackground()
            
            // 2. Main Content ScrollView
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Content Body
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Header Spacing for the image
                        Spacer().frame(height: 20)
                        
                        // Header Info & Thumbnail
                        HStack(alignment: .top, spacing: 16) {
                            AsyncImageView(filename: item.imageUrl)
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack(spacing: 8) {
                                    StatusPill(text: item.condition.uppercased(), color: conditionColor(item.condition))
                                    
                                    Text(item.category)
                                        .font(.caption.bold())
                                        .foregroundStyle(.white.opacity(0.7))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }
                            }
                            Spacer()
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // Seller Insight Card
                        Button(action: { showSellerProfile = true }) {
                            GlassCard {
                                HStack(spacing: 16) {
                                    // Avatar
                                    ZStack {
                                        if let url = ownerProfile?.avatarUrl {
                                            AsyncImageView(filename: url)
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .resizable()
                                                .foregroundStyle(.white.opacity(0.3))
                                                .frame(width: 50, height: 50)
                                        }
                                        
                                        // Rank Ring
                                        Circle()
                                            .strokeBorder(
                                                AngularGradient(colors: [.cyan, .purple, .cyan], center: .center),
                                                lineWidth: 2
                                            )
                                            .frame(width: 56, height: 56)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text(ownerProfile?.username ?? item.ownerUsername ?? "Seller")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            
                                            if ownerProfile?.isVerified == true || item.ownerIsVerified == true {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .foregroundStyle(.cyan)
                                                    .font(.caption)
                                            }
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.yellow)
                                            Text(String(format: "%.1f", ownerRating))
                                                .font(.subheadline).bold()
                                                .foregroundStyle(.white.opacity(0.9))
                                            Text("• \(ownerProfile?.completedTradeCount ?? item.ownerTradeCount ?? 0) Trades")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(12)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Description
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About this item")
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundStyle(.white)
                            
                            Text(item.description)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineSpacing(5)
                        }
                        
                        // Location Preview
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Approximate Location", systemImage: "mappin.and.ellipse")
                                    .font(.headline)
                                    .foregroundStyle(.cyan)
                                Spacer()
                                
                                // ✨ FIXED: Accessed directly without if-let
                                Text("\(String(format: "%.1f", item.distance)) km away")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            // Map Snapshot (Static for Performance)
                            if let lat = item.latitude, let lon = item.longitude {
                                ZStack(alignment: .bottomTrailing) {
                                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    )))
                                    .disabled(true)
                                    .overlay(Color.black.opacity(0.3))
                                    
                                    // Open Maps Button
                                    Button(action: { openInMaps() }) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                            .padding(12)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    }
                                    .padding(16)
                                }
                                .frame(height: 160)
                                .cornerRadius(24)
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                        
                        Spacer(minLength: 140) // Clearance for bottom bar
                    }
                    .padding(24)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // 3. Header Action Buttons (No Back Button - Swipe Down Only)
            VStack {
                // Grabber Handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                HStack {
                    Spacer()
                    
                    // Share
                    Button(action: { showShareSheet = true }) {
                        GlassNavButton(icon: "square.and.arrow.up")
                    }
                    
                    // Report
                    Button(action: { showReportActionSheet = true }) {
                        GlassNavButton(icon: "flag.fill", color: .red.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
            .allowsHitTesting(true)
            
            // 4. Floating Bottom Action Bar
            floatingActionBar
        }
        .navigationBarHidden(true)
        // Sheets & Alerts
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Check out this \(item.title) on Swappr!"])
                .presentationDetents([.medium])
        }
        .confirmationDialog("Report Item", isPresented: $showReportActionSheet) {
            Button("Inappropriate Content", role: .destructive) { submitReport(reason: "Inappropriate") }
            Button("Spam or Scam", role: .destructive) { submitReport(reason: "Spam") }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Report Received", isPresented: $showReportConfirmation) {
            Button("Done", role: .cancel) { }
        } message: {
            Text("Thank you for keeping our community safe. We will review this report shortly.")
        }
        .sheet(isPresented: $showOfferSheet) {
            QuickOfferSheet(wantedItem: item)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSellerProfile) {
            PublicProfileView(userId: item.ownerId)
        }
        .alert("Coming Soon", isPresented: $showChatAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Direct messaging will be available in the next update. Please make an offer to start a trade conversation.")
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Floating Bar
    
    var floatingActionBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                // Chat Button (Secondary)
                Button(action: { showChatAlert = true }) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                
                // Make Offer Button (Primary)
                Button(action: {
                    if !offerAlreadyPending {
                        Haptics.shared.playMedium()
                        showOfferSheet = true
                    }
                }) {
                    HStack {
                        if offerAlreadyPending {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Offer Pending")
                        } else {
                            Text("Make an Offer")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.headline.bold())
                    .foregroundStyle(offerAlreadyPending ? .white.opacity(0.6) : .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(offerAlreadyPending ? Color.gray.opacity(0.3) : Color.cyan)
                    .clipShape(Capsule())
                    .shadow(color: offerAlreadyPending ? .clear : .cyan.opacity(0.4), radius: 10, y: 5)
                }
                .disabled(offerAlreadyPending)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34) // Thumb Friendly Padding
            .padding(.top, 20)
            .background(
                LiquidBackground()
                    .opacity(0.95)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .bottom, endPoint: .top))
                    .blur(radius: 10)
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Logic (Optimized)
    
    func loadData() {
        checkIfOfferPending()
        
        // 📉 COST OPTIMIZATION: Use data we already have from Feed
        if let username = item.ownerUsername {
            self.ownerProfile = UserProfile(
                id: item.ownerId,
                username: username,
                bio: "",
                location: "",
                avatarUrl: nil,
                isoCategories: [],
                isVerified: item.ownerIsVerified ?? false,
                isPremium: item.ownerIsPremium ?? false
            )
            // Still set rating if available
            if let rating = item.ownerRating {
                self.ownerRating = rating
                self.isLoadingOwner = false
                return // Exit early! No network call needed.
            }
        }
        
        // Fallback: Only fetch from server if data is missing
        Task {
            isLoadingOwner = true
            do {
                async let profileTask = DatabaseService.shared.fetchProfile(userId: item.ownerId)
                async let ratingTask = DatabaseService.shared.fetchUserRating(userId: item.ownerId)
                
                let (profile, rating) = try await (profileTask, ratingTask)
                
                await MainActor.run {
                    self.ownerProfile = profile
                    self.ownerRating = rating
                    self.isLoadingOwner = false
                }
            } catch {
                await MainActor.run { isLoadingOwner = false }
            }
        }
    }
    
    func checkIfOfferPending() {
        Task {
            // This is a quick DB check, essential for logic
            let exists = await TradeManager.shared.hasPendingOffer(for: item.id)
            await MainActor.run { withAnimation { self.offerAlreadyPending = exists } }
        }
    }
    
    func submitReport(reason: String) {
        guard let userId = UserManager.shared.currentUser?.id else { return }
        Task {
            try? await DatabaseService.shared.reportItem(itemId: item.id, userId: userId, reason: reason)
            await MainActor.run {
                self.showReportConfirmation = true
            }
        }
    }
    
    func openInMaps() {
        guard let lat = item.latitude, let lon = item.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = "Trade Location"
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    func conditionColor(_ condition: String) -> Color {
        switch condition.lowercased() {
        case "new": return .green
        case "like new": return .mint
        case "good": return .blue
        case "fair": return .orange
        case "poor": return .red
        default: return .gray
        }
    }
}

// MARK: - Helpers

struct StatusPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.8))
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

struct GlassNavButton: View {
    let icon: String
    var color: Color = .white
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(LinearGradient(colors: [color.opacity(0.3), Color.white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    var applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
