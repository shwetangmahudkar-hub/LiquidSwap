import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct ChatRoomView: View {
    let trade: TradeOffer
    
    @ObservedObject var chatManager = ChatManager.shared
    @ObservedObject var userManager = UserManager.shared
    
    @Environment(\.dismiss) var dismiss
    
    @State private var newMessageText = ""
    @FocusState private var isFocused: Bool
    
    // State
    @State private var showRatingSheet = false
    @State private var isCompletingTrade = false
    @State private var showNoTradeAlert = false
    @State private var partnerName = "Trading Partner"
    @State private var showDealDashboard = true
    @State private var showSafeMap = false
    
    // Safety Alerts
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    
    // Counter Offer State
    @State private var showCounterSheet = false
    
    // Premium State
    @State private var showPremiumPaywall = false
    
    // Photo State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedCameraImage: UIImage?
    @State private var showCamera = false
    @State private var isSendingImage = false
    @State private var showAttachmentOptions = false
    
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
                // Deal Dashboard
                DealDashboard(
                    trade: trade,
                    isExpanded: $showDealDashboard,
                    currentUserId: UserManager.shared.currentUser?.id,
                    onCounter: { showCounterSheet = true }
                )
                .zIndex(10)
                
                messageListSection
                    .onTapGesture { dismissKeyboard() }
            }
        }
        .navigationTitle(partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
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
                    
                    Menu {
                        Button(role: .destructive, action: { showBlockAlert = true }) {
                            Label("Block User", systemImage: "hand.raised.fill")
                        }
                        
                        Button(action: { showReportAlert = true }) {
                            Label("Report User", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChatInputBar(
                text: $newMessageText,
                isPremium: userManager.isPremium,
                onSend: sendMessage,
                onMapTap: { showSafeMap = true },
                onCameraTap: {
                    if userManager.isPremium {
                        showCamera = true
                    } else {
                        showPremiumPaywall = true
                    }
                },
                onPhotoTap: {
                    if !userManager.isPremium {
                        showPremiumPaywall = true
                    }
                },
                selectedPhotoItem: $selectedPhotoItem,
                showOptions: $showAttachmentOptions
            )
        }
        .onAppear {
            TabBarManager.shared.hide()
            fetchPartnerProfile()
        }
        .onDisappear { TabBarManager.shared.show() }
        .sheet(isPresented: $showPremiumPaywall) {
            PremiumUpgradeSheet()
                .presentationDetents([.fraction(0.6)])
        }
        .chatRoomSheetsAndAlerts(
            trade: trade,
            partnerId: partnerId,
            partnerName: partnerName,
            showRatingSheet: $showRatingSheet,
            showNoTradeAlert: $showNoTradeAlert,
            showBlockAlert: $showBlockAlert,
            showReportAlert: $showReportAlert,
            showSafeMap: $showSafeMap,
            showCounterSheet: $showCounterSheet,
            showCamera: $showCamera,
            selectedCameraImage: $selectedCameraImage,
            selectedPhotoItem: $selectedPhotoItem,
            isSendingImage: $isSendingImage,
            showAttachmentOptions: $showAttachmentOptions,
            chatManager: chatManager,
            dismiss: dismiss
        )
    }
    
    // MARK: - Message List
    
    private var messageListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 10)
                    
                    let sections = groupedMessages
                    
                    if sections.isEmpty {
                        Text("Start the conversation!")
                            .appFont(12)
                            .foregroundStyle(.gray)
                            .padding(.top, 40)
                    }
                    
                    ForEach(sections, id: \.date) { section in
                        Section(header: DateHeader(date: section.date)) {
                            ForEach(section.messages, id: \.id) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                                    .padding(.bottom, 12)
                            }
                        }
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
            .onChange(of: chatManager.conversations[trade.id]?.count) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
    
    struct MessageSection {
        let date: Date
        let messages: [Message]
    }
    
    var groupedMessages: [MessageSection] {
        let messages = chatManager.conversations[trade.id] ?? []
        let grouped = Dictionary(grouping: messages) { (message) -> Date in
            Calendar.current.startOfDay(for: message.createdAt)
        }
        return grouped.keys.sorted().map { date in
            MessageSection(date: date, messages: grouped[date]!.sorted { $0.createdAt < $1.createdAt })
        }
    }
    
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func sendMessage() {
        guard !newMessageText.isEmpty else { return }
        let text = newMessageText
        newMessageText = ""
        Task { await chatManager.sendMessage(text, to: partnerId, tradeId: trade.id) }
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

// MARK: - Date Header
struct DateHeader: View {
    let date: Date
    
    var body: some View {
        Text(dateFormatter.string(from: date))
            .appFont(10, weight: .bold)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Today'"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday'"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter
    }
}

// MARK: - Modifiers Extension

extension View {
    func chatRoomSheetsAndAlerts(
        trade: TradeOffer,
        partnerId: UUID,
        partnerName: String,
        showRatingSheet: Binding<Bool>,
        showNoTradeAlert: Binding<Bool>,
        showBlockAlert: Binding<Bool>,
        showReportAlert: Binding<Bool>,
        showSafeMap: Binding<Bool>,
        showCounterSheet: Binding<Bool>,
        showCamera: Binding<Bool>,
        selectedCameraImage: Binding<UIImage?>,
        selectedPhotoItem: Binding<PhotosPickerItem?>,
        isSendingImage: Binding<Bool>,
        showAttachmentOptions: Binding<Bool>,
        chatManager: ChatManager,
        dismiss: DismissAction
    ) -> some View {
        self
            .fullScreenCover(isPresented: showCamera) {
                CameraPicker(selectedImage: selectedCameraImage).ignoresSafeArea()
            }
            .sheet(isPresented: showRatingSheet) {
                RateUserView(targetUserId: partnerId, targetUsername: partnerName)
            }
            .sheet(isPresented: showSafeMap) {
                // Safe Map Logic
                let userLoc = LocationManager.shared.userLocation?.coordinate
                let start = getCoordinate(for: trade.offeredItem) ?? userLoc ?? CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
                let end = getCoordinate(for: trade.wantedItem) ?? userLoc ?? CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
                
                SafeMeetingPointView(
                    locationA: start,
                    locationB: end,
                    onSendLocation: { name, _ in
                        let msg = "桃 Let's meet at **\(name)**. It's a Verified Safe Zone."
                        Task { await chatManager.sendMessage(msg, to: partnerId, tradeId: trade.id) }
                        showSafeMap.wrappedValue = false
                    }
                )
            }
            .sheet(isPresented: showCounterSheet) {
                CounterOfferSheet(originalTrade: trade)
                    .presentationDetents([.medium, .large])
            }
            .alert("No Trade Found", isPresented: showNoTradeAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This trade is no longer active.")
            }
            .alert("Block User?", isPresented: showBlockAlert) {
                Button("Block", role: .destructive) {
                    Task {
                        await UserManager.shared.blockUser(userId: partnerId)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You will no longer receive messages from this user.")
            }
            .alert("Report User?", isPresented: showReportAlert) {
                Button("Spam", role: .destructive) { reportUser(id: partnerId, reason: "Spam") }
                Button("Abusive", role: .destructive) { reportUser(id: partnerId, reason: "Abusive") }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please select a reason for reporting.")
            }
            .onChange(of: selectedPhotoItem.wrappedValue) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run { isSendingImage.wrappedValue = true }
                        await chatManager.sendImage(data: data, to: partnerId, tradeId: trade.id)
                        await MainActor.run {
                            isSendingImage.wrappedValue = false
                            selectedPhotoItem.wrappedValue = nil
                        }
                        withAnimation { showAttachmentOptions.wrappedValue = false }
                    }
                }
            }
            .onChange(of: selectedCameraImage.wrappedValue) { newImage in
                if let image = newImage, let data = image.jpegData(compressionQuality: 0.7) {
                    Task {
                        await MainActor.run { isSendingImage.wrappedValue = true }
                        await chatManager.sendImage(data: data, to: partnerId, tradeId: trade.id)
                        await MainActor.run {
                            isSendingImage.wrappedValue = false
                            selectedCameraImage.wrappedValue = nil
                        }
                        withAnimation { showAttachmentOptions.wrappedValue = false }
                    }
                }
            }
    }
    
    func getCoordinate(for item: TradeItem?) -> CLLocationCoordinate2D? {
        guard let lat = item?.latitude, let lon = item?.longitude,
              lat != 0, lon != 0,
              !lat.isNaN, !lon.isNaN else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func reportUser(id: UUID, reason: String) {
        guard let myId = UserManager.shared.currentUser?.id else { return }
        Task {
            try? await DatabaseService.shared.reportUser(reporterId: myId, reportedId: id, reason: reason)
        }
    }
}

// MARK: - DASHBOARD SUBVIEWS
struct DealDashboard: View {
    let trade: TradeOffer
    @Binding var isExpanded: Bool
    let currentUserId: UUID?
    var onCounter: () -> Void
    
    var iAmSender: Bool {
        return trade.senderId == currentUserId
    }
    
    var myItems: [TradeItem] {
        return iAmSender ? trade.allOfferedItems : trade.allWantedItems
    }
    
    var theirItems: [TradeItem] {
        return iAmSender ? trade.allWantedItems : trade.allOfferedItems
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "hand.thumbsup.fill").foregroundStyle(.cyan)
                    Text(isExpanded ? "Current Deal" : "Show Deal Details")
                        .appFont(12, weight: .bold).foregroundStyle(.white)
                    Spacer()
                    
                    if !isExpanded {
                        Text("\(theirItems.count) for \(myItems.count)")
                            .appFont(10, weight: .bold).foregroundStyle(.gray)
                    }
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0)).foregroundStyle(.gray)
                }
                .padding(.horizontal, 16).padding(.vertical, 12).background(.ultraThinMaterial)
            }
            
            // Expanded View
            if isExpanded {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        
                        // LEFT: YOU GET
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You Get (\(theirItems.count))")
                                .appFont(10, weight: .bold)
                                .foregroundStyle(.cyan)
                                .padding(.leading, 8)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if theirItems.isEmpty {
                                        Text("None").appFont(10).foregroundStyle(.gray).padding(8)
                                    } else {
                                        ForEach(theirItems) { item in MiniItemPill(item: item) }
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // CENTER: SWAP ICON
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(.white.opacity(0.3))
                            .font(.title3)
                            .padding(.top, 30)
                        
                        // RIGHT: YOU GIVE
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("You Give (\(myItems.count))")
                                .appFont(10, weight: .bold)
                                .foregroundStyle(.purple)
                                .padding(.trailing, 8)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if myItems.isEmpty {
                                        Text("None").appFont(10).foregroundStyle(.gray).padding(8)
                                    } else {
                                        ForEach(myItems) { item in MiniItemPill(item: item) }
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            .flipsForRightToLeftLayoutDirection(true)
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)
                    
                    // STATUS BAR
                    if trade.status == "pending" {
                        if trade.receiverId == currentUserId {
                            Button(action: onCounter) {
                                Text("Counter Offer")
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .orange, textColor: .white)) // ✨ Updated Button Style
                            .frame(width: 140)
                            .padding(.bottom, 12)
                        } else {
                            Text("Waiting for partner response...")
                                .appFont(10).italic().foregroundStyle(.gray)
                                .padding(.bottom, 12)
                        }
                    } else {
                        Text("Status: \(trade.status.capitalized)")
                            .appFont(12, weight: .bold)
                            .foregroundStyle(trade.status == "accepted" ? .green : .gray)
                            .padding(.bottom, 12)
                    }
                }
                .background(Color.black.opacity(0.3))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.1)), alignment: .bottom)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: .black.opacity(0.2), radius: 5, y: 5)
    }
}

struct MiniItemPill: View {
    let item: TradeItem
    var body: some View {
        VStack(spacing: 4) {
            AsyncImageView(filename: item.imageUrl)
                .frame(width: 44, height: 44)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            Text(item.title)
                .appFont(9)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .frame(width: 44)
        }
    }
}

// MARK: - INPUT AND BUBBLE SUBVIEWS

struct ChatInputBar: View {
    @Binding var text: String
    let isPremium: Bool
    var onSend: () -> Void
    var onMapTap: () -> Void
    var onCameraTap: () -> Void
    var onPhotoTap: () -> Void
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var showOptions: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            if showOptions {
                VStack(spacing: 16) {
                    // Buttons Logic (Preserved)
                    Button(action: { onMapTap(); withAnimation { showOptions = false } }) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title3).foregroundStyle(.green).frame(width: 30, height: 30)
                    }
                    Button(action: { onCameraTap(); withAnimation { if isPremium { showOptions = false } } }) {
                        ZStack {
                            Image(systemName: "camera.fill").font(.title3).foregroundStyle(.white)
                            if !isPremium { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.yellow).offset(x: 10, y: -10) }
                        }.frame(width: 30, height: 30)
                    }
                    if isPremium {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: "photo.on.rectangle").font(.title3).foregroundStyle(.white).frame(width: 30, height: 30)
                        }
                    } else {
                        Button(action: onPhotoTap) {
                            ZStack {
                                Image(systemName: "photo.on.rectangle").font(.title3).foregroundStyle(.white)
                                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.yellow).offset(x: 10, y: -10)
                            }.frame(width: 30, height: 30)
                        }
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                .padding(.leading, 12).padding(.bottom, 8)
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showOptions.toggle() } }) {
                    Image(systemName: showOptions ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.title2).foregroundStyle(showOptions ? .gray : .cyan)
                        .padding(8).background(Color.white.opacity(0.1)).clipShape(Circle())
                }

                TextField("Message...", text: $text, axis: .vertical)
                    .appFont(16) // ✨ Standardized
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
            .padding(.horizontal).padding(.top, 12).padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
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
                        case .failure: Image(systemName: "photo.badge.exclamationmark").frame(width: 200, height: 200).foregroundStyle(.red)
                        @unknown default: EmptyView()
                        }
                    }
                    .cornerRadius(18).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                if !message.content.isEmpty && message.content != "Sent an image" {
                    if message.content.contains("桃 Let's meet at") {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill").font(.title).foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PROPOSED MEETUP").font(.system(size: 8, weight: .black)).foregroundStyle(.green)
                                Text(message.content.replacingOccurrences(of: "桃 ", with: "")).appFont(12).foregroundStyle(.white)
                            }
                        }
                        .padding(12).background(Color.black.opacity(0.4)).cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.5), lineWidth: 1))
                    } else {
                        Text(message.content)
                            .appFont(16) // ✨ Standardized
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(message.isCurrentUser ? Color.cyan : Color.white.opacity(0.15))
                            .foregroundStyle(message.isCurrentUser ? .black : .white)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: message.isCurrentUser ? 18 : 2, bottomTrailingRadius: message.isCurrentUser ? 2 : 18, topTrailingRadius: 18))
                    }
                }
                Text(message.createdAt.formatted(.dateTime.hour().minute())).appFont(10).foregroundStyle(.gray).padding(.horizontal, 4)
            }
            if !message.isCurrentUser { Spacer() }
        }
    }
}

// MARK: - SAFE MAP SUBVIEWS

struct SafeSpotItem: Identifiable {
    let id = UUID()
    let item: MKMapItem
}

struct SafeMeetingPointView: View {
    let locationA: CLLocationCoordinate2D
    let locationB: CLLocationCoordinate2D
    var onSendLocation: (String, CLLocationCoordinate2D) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var safeSpots: [SafeSpotItem] = []
    @State private var isLoading = false
    @State private var selectedSpot: SafeSpotItem?
    @State private var legacyRegion: MKCoordinateRegion
    
    init(locationA: CLLocationCoordinate2D, locationB: CLLocationCoordinate2D, onSendLocation: @escaping (String, CLLocationCoordinate2D) -> Void) {
        self.locationA = locationA
        self.locationB = locationB
        self.onSendLocation = onSendLocation
        
        let validA = (locationA.latitude != 0 && locationA.longitude != 0)
        let validB = (locationB.latitude != 0 && locationB.longitude != 0)
        
        let centerLat = validA && validB ? (locationA.latitude + locationB.latitude) / 2 : (validA ? locationA.latitude : 0)
        let centerLon = validA && validB ? (locationA.longitude + locationB.longitude) / 2 : (validA ? locationA.longitude : 0)
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        
        _legacyRegion = State(initialValue: MKCoordinateRegion(center: center, span: span))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if #available(iOS 17.0, *) {
                        ModernSafeMapAdapter(safeSpots: safeSpots, selectedSpot: $selectedSpot, initialCenter: legacyRegion.center)
                    } else {
                        Map(coordinateRegion: $legacyRegion, annotationItems: safeSpots) { spotWrapper in
                            MapAnnotation(coordinate: spotWrapper.item.placemark.coordinate) { mapIcon(for: spotWrapper) }
                        }
                        .ignoresSafeArea(edges: .bottom)
                    }
                }
                
                VStack {
                    Spacer()
                    if let selected = selectedSpot {
                        VStack(spacing: 12) {
                            Text(selected.item.name ?? "Safe Spot")
                                .appFont(18, weight: .bold).foregroundStyle(.white)
                            
                            HStack(spacing: 12) {
                                Button(action: { openInMaps(item: selected.item) }) {
                                    HStack { Image(systemName: "car.fill"); Text("Directions") }
                                }
                                .buttonStyle(PrimaryButtonStyle(color: .white, textColor: .black)) // ✨ Standardized
                                
                                Button(action: {
                                    onSendLocation(selected.item.name ?? "Safe Spot", selected.item.placemark.coordinate)
                                }) {
                                    HStack { Image(systemName: "paperplane.fill"); Text("Send to Chat") }
                                }
                                .buttonStyle(PrimaryButtonStyle(color: .blue, textColor: .white)) // ✨ Standardized
                            }
                        }
                        .padding(20).background(.ultraThinMaterial).cornerRadius(20).shadow(radius: 10)
                        .padding(.horizontal).padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white).scaleEffect(1.5)
                            Text("Finding Safe Spots...").appFont(16, weight: .bold).foregroundStyle(.white)
                        }
                        .padding(20).background(.ultraThinMaterial).cornerRadius(16)
                    }
                }
            }
            .navigationTitle("Safe Meeting Point").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onAppear { findSafeSpotsParallel() }
        }
    }
    
    func mapIcon(for spotWrapper: SafeSpotItem) -> some View {
        Button(action: { withAnimation { selectedSpot = spotWrapper } }) {
            ZStack {
                Image(systemName: "shield.fill").font(.system(size: 40)).foregroundStyle(.green).shadow(radius: 5)
                Image(systemName: getIcon(for: spotWrapper.item)).font(.caption).bold().foregroundStyle(.white).offset(y: -2)
            }
            .scaleEffect(selectedSpot?.id == spotWrapper.id ? 1.2 : 1.0)
        }
    }
    
    func getIcon(for spot: MKMapItem) -> String {
        spot.pointOfInterestCategory == .police ? "lock.shield.fill" : "cup.and.saucer.fill"
    }
    
    func findSafeSpotsParallel() {
        isLoading = true
        Task {
            let midLat = (locationA.latitude + locationB.latitude) / 2
            let midLon = (locationA.longitude + locationB.longitude) / 2
            let searchRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            
            let categories = ["Police Station", "Coffee Shop", "Library", "Community Centre"]
            var allItems: [MKMapItem] = []
            
            for category in categories {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = category
                request.region = searchRegion
                if let response = try? await MKLocalSearch(request: request).start() {
                    allItems.append(contentsOf: response.mapItems)
                }
            }
            
            await MainActor.run {
                self.safeSpots = Array(Set(allItems)).prefix(10).map { SafeSpotItem(item: $0) }
                self.isLoading = false
            }
        }
    }
    
    func openInMaps(item: MKMapItem) {
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - iOS 17 Adapter
@available(iOS 17.0, *)
struct ModernSafeMapAdapter: View {
    let safeSpots: [SafeSpotItem]
    @Binding var selectedSpot: SafeSpotItem?
    let initialCenter: CLLocationCoordinate2D
    
    @State private var position: MapCameraPosition
    
    init(safeSpots: [SafeSpotItem], selectedSpot: Binding<SafeSpotItem?>, initialCenter: CLLocationCoordinate2D) {
        self.safeSpots = safeSpots
        self._selectedSpot = selectedSpot
        self.initialCenter = initialCenter
        
        let region = MKCoordinateRegion(center: initialCenter, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        self._position = State(initialValue: .region(region))
    }
    
    var body: some View {
        Map(position: $position) {
            ForEach(safeSpots) { spotWrapper in
                Annotation(spotWrapper.item.name ?? "Safe Spot", coordinate: spotWrapper.item.placemark.coordinate) {
                    mapIcon(for: spotWrapper)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    func mapIcon(for spotWrapper: SafeSpotItem) -> some View {
        Button(action: { withAnimation { selectedSpot = spotWrapper } }) {
            ZStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .shadow(radius: 5)
                
                Image(systemName: getIcon(for: spotWrapper.item))
                    .font(.caption).bold()
                    .foregroundStyle(.white)
                    .offset(y: -2)
            }
            .scaleEffect(selectedSpot?.id == spotWrapper.id ? 1.2 : 1.0)
        }
    }
    
    func getIcon(for spot: MKMapItem) -> String {
        spot.pointOfInterestCategory == .police ? "lock.shield.fill" : "cup.and.saucer.fill"
    }
}
