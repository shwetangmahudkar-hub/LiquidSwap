import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct ChatRoomView: View {
    // ✅ CRITICAL FIX: Pass the full trade object.
    // This ensures we have the correct ID immediately.
    let trade: TradeOffer
    
    @ObservedObject var chatManager = ChatManager.shared
    @State private var newMessageText = ""
    @FocusState private var isFocused: Bool
    
    // State
    @State private var showRatingSheet = false
    @State private var isCompletingTrade = false
    @State private var showNoTradeAlert = false
    @State private var partnerName = "Trading Partner"
    @State private var showDealDashboard = true
    @State private var showSafeMap = false
    
    // Photo State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedCameraImage: UIImage?
    @State private var showCamera = false
    @State private var isSendingImage = false
    
    // ✅ FIX: Robust Partner ID
    // Uses ChatManager's trusted ID. If that fails, defaults to trade receiver to prevent crash.
    var partnerId: UUID {
        guard let myId = chatManager.currentUserId ?? UserManager.shared.currentUser?.id else {
            return trade.receiverId
        }
        return (trade.senderId == myId) ? trade.receiverId : trade.senderId
    }
    
    var body: some View {
        ZStack {
            LiquidBackground()
            
            VStack(spacing: 0) {
                DealDashboard(trade: trade, isExpanded: $showDealDashboard)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                
                messageListSection
                    .onTapGesture { dismissKeyboard() }
            }
        }
        .navigationTitle(partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    completeTradeAction()
                } label: {
                    if isCompletingTrade {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.cyan)
                    }
                }
                .disabled(isCompletingTrade)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputBar(
                text: $newMessageText,
                onSend: sendMessage,
                onMapTap: { showSafeMap = true },
                onCameraTap: { showCamera = true },
                isMapEnabled: hasLocationData,
                selectedPhotoItem: $selectedPhotoItem
            )
        }
        .onAppear {
            TabBarManager.shared.hide()
            fetchPartnerProfile()
            // We do NOT need to fetchActiveTrade anymore, we have it!
        }
        .onDisappear { TabBarManager.shared.show() }
        
        // --- HANDLERS ---
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem = newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await sendImageData(data)
                    await MainActor.run { selectedPhotoItem = nil }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedCameraImage).ignoresSafeArea()
        }
        .onChange(of: selectedCameraImage) { _, newImage in
            if let image = newImage, let data = image.jpegData(compressionQuality: 0.7) {
                Task {
                    await sendImageData(data)
                    await MainActor.run { selectedCameraImage = nil }
                }
            }
        }
        .alert("No Trade Found", isPresented: $showNoTradeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This trade is no longer active.")
        }
        .sheet(isPresented: $showRatingSheet) {
            RateUserView(targetUserId: partnerId, targetUsername: partnerName)
        }
        .sheet(isPresented: $showSafeMap) {
            if let loc1 = getCoordinate(for: trade.offeredItem),
               let loc2 = getCoordinate(for: trade.wantedItem) {
                SafeMeetingPointView(locationA: loc1, locationB: loc2)
            } else {
                Text("Location data unavailable.").presentationDetents([.fraction(0.3)])
            }
        }
    }
    
    // MARK: - Logic
    
    private var messageListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 10)
                    
                    // ✅ CRITICAL FIX: Use trade.id directly. No guessing.
                    let messages = chatManager.conversations[trade.id] ?? []
                    
                    if messages.isEmpty {
                        Text("Start the conversation!")
                            .font(.caption).foregroundStyle(.gray).padding(.top, 40)
                    }
                    
                    ForEach(messages, id: \.id) { message in
                        MessageBubble(message: message).id(message.id)
                    }
                    
                    if isSendingImage {
                        HStack { Spacer(); ProgressView().tint(.white).padding().background(Color.white.opacity(0.1)).clipShape(Circle()) }
                            .padding(.horizontal).id("uploading")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chatManager.conversations[trade.id]?.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
    
    var hasLocationData: Bool {
        return getCoordinate(for: trade.offeredItem) != nil && getCoordinate(for: trade.wantedItem) != nil
    }
    
    func getCoordinate(for item: TradeItem?) -> CLLocationCoordinate2D? {
        guard let lat = item?.latitude, let lon = item?.longitude, lat != 0, lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func sendMessage() {
        guard !newMessageText.isEmpty else { return }
        let text = newMessageText
        newMessageText = ""
        // ✅ CRITICAL FIX: Use trade.id directly
        Task { await chatManager.sendMessage(text, to: partnerId, tradeId: trade.id) }
    }
    
    func sendImageData(_ data: Data) async {
        await MainActor.run { isSendingImage = true }
        // ✅ CRITICAL FIX: Use trade.id directly
        await chatManager.sendImage(data: data, to: partnerId, tradeId: trade.id)
        await MainActor.run { isSendingImage = false }
    }
    
    func completeTradeAction() {
        isCompletingTrade = true
        Task {
            let success = await TradeManager.shared.completeTrade(with: partnerId)
            isCompletingTrade = false
            if success {
                Haptics.shared.playSuccess()
                showRatingSheet = true
            } else {
                Haptics.shared.playError()
                showNoTradeAlert = true
            }
        }
    }
    
    func fetchPartnerProfile() {
        Task {
            if let profile = try? await DatabaseService.shared.fetchProfile(userId: partnerId) {
                await MainActor.run { self.partnerName = profile.username }
            }
        }
    }
}

// MARK: - SUBVIEWS

struct DealDashboard: View {
    let trade: TradeOffer
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "hand.thumbsup.fill").foregroundStyle(.cyan)
                    Text(isExpanded ? "Current Deal" : "Show Deal Details")
                        .font(.caption).bold().foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0)).foregroundStyle(.gray)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(.ultraThinMaterial)
            }
            
            if isExpanded {
                HStack(spacing: 0) {
                    VStack {
                        Text("You Get").font(.caption2).foregroundStyle(.gray)
                        AsyncImageView(filename: trade.offeredItem?.imageUrl)
                            .frame(width: 50, height: 50).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                        Text(trade.offeredItem?.title ?? "?")
                            .font(.caption2).bold().foregroundStyle(.white).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(.cyan).font(.title3).padding(.horizontal, 8)
                    
                    VStack {
                        Text("You Give").font(.caption2).foregroundStyle(.gray)
                        AsyncImageView(filename: trade.wantedItem?.imageUrl)
                            .frame(width: 50, height: 50).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                        Text(trade.wantedItem?.title ?? "?")
                            .font(.caption2).bold().foregroundStyle(.white).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12).background(Color.black.opacity(0.3))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.1)), alignment: .bottom)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
    }
}

struct ChatInputBar: View {
    @Binding var text: String
    var onSend: () -> Void
    var onMapTap: () -> Void
    var onCameraTap: () -> Void
    var isMapEnabled: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Menu {
                Button(action: onMapTap) { Label("Safe Meeting Point", systemImage: "shield.check.fill") }
                    .disabled(!isMapEnabled)
                Button(action: onCameraTap) { Label("Take Photo", systemImage: "camera.fill") }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) { Label("Photo Library", systemImage: "photo.on.rectangle") }
            } label: {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.cyan)
                    .padding(8).background(Color.white.opacity(0.1)).clipShape(Circle())
            }

            TextField("Message...", text: $text, axis: .vertical)
                .padding(12).background(Color.white.opacity(0.1)).cornerRadius(20)
                .foregroundStyle(.white).lineLimit(1...5)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 38))
                    .foregroundStyle(text.isEmpty ? .gray : .cyan)
                    .shadow(color: text.isEmpty ? .clear : .cyan.opacity(0.5), radius: 5)
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal).padding(.top, 12).padding(.bottom, 8).background(.ultraThinMaterial)
    }
}

struct MessageBubble: View {
    let message: Message
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isCurrentUser { Spacer() }
            VStack(alignment: message.isCurrentUser ? .trailing : .leading, spacing: 4) {
                if let imageUrl = message.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty: ProgressView().frame(width: 200, height: 200).background(Color.gray.opacity(0.3))
                        case .success(let image): image.resizable().scaledToFill().frame(width: 200, height: 200).clipped()
                        case .failure: Image(systemName: "photo.badge.exclamationmark").frame(width: 200, height: 200).background(Color.gray.opacity(0.3)).foregroundStyle(.red)
                        @unknown default: EmptyView()
                        }
                    }
                    .cornerRadius(18).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                if !message.content.isEmpty && message.content != "Sent an image" {
                    Text(message.content)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(message.isCurrentUser ? Color.cyan : Color.white.opacity(0.15))
                        .foregroundStyle(message.isCurrentUser ? .black : .white)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: message.isCurrentUser ? 18 : 2, bottomTrailingRadius: message.isCurrentUser ? 2 : 18, topTrailingRadius: 18))
                }
                Text(message.createdAt.formatted(.dateTime.hour().minute())).font(.caption2).foregroundStyle(.gray).padding(.horizontal, 4)
            }
            if !message.isCurrentUser { Spacer() }
        }
    }
}

struct SafeSpotItem: Identifiable {
    let id = UUID()
    let item: MKMapItem
}

struct SafeMeetingPointView: View {
    let locationA: CLLocationCoordinate2D
    let locationB: CLLocationCoordinate2D
    @Environment(\.dismiss) var dismiss
    @State private var position: MapCameraPosition
    @State private var safeSpots: [SafeSpotItem] = []
    @State private var isLoading = false
    @State private var selectedSpot: SafeSpotItem?
    
    init(locationA: CLLocationCoordinate2D, locationB: CLLocationCoordinate2D) {
        self.locationA = locationA
        self.locationB = locationB
        let midLat = (locationA.latitude + locationB.latitude) / 2
        let midLon = (locationA.longitude + locationB.longitude) / 2
        let center = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        _position = State(initialValue: .region(MKCoordinateRegion(center: center, span: span)))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    ForEach(safeSpots) { spotWrapper in
                        Annotation(spotWrapper.item.name ?? "Safe Spot", coordinate: spotWrapper.item.placemark.coordinate) {
                            Button(action: { selectedSpot = spotWrapper }) {
                                Image(systemName: getIcon(for: spotWrapper.item)).padding(8).background(Color.green).clipShape(Circle()).foregroundStyle(.white).shadow(radius: 4).scaleEffect(selectedSpot?.id == spotWrapper.id ? 1.2 : 1.0)
                            }
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                
                VStack {
                    Spacer()
                    if let selected = selectedSpot {
                        Button(action: { openInMaps(item: selected.item) }) {
                            HStack { Image(systemName: "map.fill"); Text("Get Directions to \(selected.item.name ?? "Spot")") }
                                .font(.headline).foregroundStyle(.white).padding().frame(maxWidth: .infinity).background(Color.blue).cornerRadius(15).shadow(radius: 5)
                        }
                        .padding(.horizontal).padding(.bottom, 20)
                    }
                }
                
                if isLoading {
                    ZStack { Color.black.opacity(0.3).ignoresSafeArea(); VStack(spacing: 12) { ProgressView().tint(.white).scaleEffect(1.5); Text("Finding Safe Spots...").font(.headline).foregroundStyle(.white) }.padding(20).background(.ultraThinMaterial).cornerRadius(16) }
                }
            }
            .navigationTitle("Safe Meeting Point").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onAppear { findSafeSpotsParallel() }
        }
    }
    
    func getIcon(for spot: MKMapItem) -> String { spot.pointOfInterestCategory == .police ? "shield.fill" : "cup.and.saucer.fill" }
    
    func findSafeSpotsParallel() {
        isLoading = true
        Task {
            let midLat = (locationA.latitude + locationB.latitude) / 2
            let midLon = (locationA.longitude + locationB.longitude) / 2
            let searchRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            let categories = ["Police Station", "Coffee Shop", "Library"]
            var allItems: [MKMapItem] = []
            for category in categories {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = category
                request.region = searchRegion
                if let response = try? await MKLocalSearch(request: request).start() { allItems.append(contentsOf: response.mapItems) }
            }
            await MainActor.run { self.safeSpots = Array(Set(allItems)).prefix(10).map { SafeSpotItem(item: $0) }; self.isLoading = false }
        }
    }
    
    func openInMaps(item: MKMapItem) { item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]) }
}
