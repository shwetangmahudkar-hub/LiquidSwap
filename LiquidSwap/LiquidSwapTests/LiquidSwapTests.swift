import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct ChatRoomView: View {
    let trade: TradeOffer
    
    // MARK: - Managers
    @ObservedObject var chatManager = ChatManager.shared
    @ObservedObject var userManager = UserManager.shared
    @ObservedObject var tradeManager = TradeManager.shared
    
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Input State
    @State private var newMessageText = ""
    @FocusState private var isFocused: Bool
    
    // MARK: - Trade State
    @State private var showRatingSheet = false
    @State private var isCompletingTrade = false
    @State private var showNoTradeAlert = false
    @State private var partnerName = "Trading Partner"
    @State private var showDealDashboard = true // Default to visible for context
    @State private var showSafeMap = false
    
    // MARK: - Celebration State
    @State private var showCompletionCelebration = false
    
    // MARK: - Safety Alerts
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    
    // MARK: - Counter Offer
    @State private var showCounterSheet = false
    
    // MARK: - Premium & Media State
    @State private var showPremiumPaywall = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedCameraImage: UIImage?
    @State private var showCamera = false
    @State private var isSendingImage = false
    @State private var showAttachmentOptions = false
    
    // MARK: - Computed Properties
    var myId: UUID? { userManager.currentUser?.id }
    
    var partnerId: UUID {
        guard let myId = myId else { return trade.receiverId }
        return (trade.senderId == myId) ? trade.receiverId : trade.senderId
    }
    
    // Live messages from ChatManager (Specific to this trade)
    var messages: [Message] {
        return chatManager.conversations[trade.id] ?? []
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // 1. Global Background
            LiquidBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Custom Glass Header
                customHeader
                    .zIndex(100)
                
                // 3. Deal Dashboard (Collapsible)
                DealDashboard(
                    trade: trade,
                    isExpanded: $showDealDashboard,
                    currentUserId: myId,
                    onCounter: { showCounterSheet = true }
                )
                .zIndex(90)
                
                // 4. Message List
                messageListSection
                    .onTapGesture {
                        dismissKeyboard()
                        withAnimation { showAttachmentOptions = false }
                    }
            }
            
            // 5. Celebration Overlay
            if showCompletionCelebration {
                TradeCompletionOverlay(onDismiss: {
                    showCompletionCelebration = false
                    showRatingSheet = true
                })
                .zIndex(200)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .navigationBarHidden(true)
        
        // MARK: - Input Bar (Bottom Inset)
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
                    // Handled by PhotosPicker in subview
                },
                selectedPhotoItem: $selectedPhotoItem,
                showOptions: $showAttachmentOptions
            )
        }
        .onAppear {
            TabBarManager.shared.hide()
            fetchPartnerProfile()
            
            // 📉 OPTIMIZATION: Load ONLY this chat's history
            Task {
                await chatManager.loadChat(tradeId: trade.id)
            }
        }
        .onDisappear { TabBarManager.shared.show() }
        
        // MARK: - Sheets & Alerts
        .sheet(isPresented: $showPremiumPaywall) {
            PremiumUpgradeSheet()
                .presentationDetents([.fraction(0.6)])
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedCameraImage).ignoresSafeArea()
        }
        .sheet(isPresented: $showRatingSheet) {
            RateUserView(targetUserId: partnerId, targetUsername: partnerName)
        }
        .sheet(isPresented: $showCounterSheet) {
            CounterOfferSheet(originalTrade: trade)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSafeMap) {
            // Calculate midpoint or default to user location
            let userLoc = LocationManager.shared.userLocation?.coordinate
            let start = getCoordinate(for: trade.offeredItem) ?? userLoc ?? CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
            let end = getCoordinate(for: trade.wantedItem) ?? userLoc ?? CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
            
            SafeMeetingPointView(
                locationA: start,
                locationB: end,
                onSendLocation: { name, _ in
                    let msg = "📍 Let's meet at **\(name)**. It's a Verified Safe Zone."
                    Task { await chatManager.sendMessage(msg, to: partnerId, tradeId: trade.id) }
                    showSafeMap = false
                }
            )
        }
        .alert("No Trade Found", isPresented: $showNoTradeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This trade is no longer active.")
        }
        .alert("Block User?", isPresented: $showBlockAlert) {
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
        .alert("Report User?", isPresented: $showReportAlert) {
            Button("Spam", role: .destructive) { reportUser(id: partnerId, reason: "Spam") }
            Button("Abusive", role: .destructive) { reportUser(id: partnerId, reason: "Abusive") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please select a reason for reporting.")
        }
        // Handle Media Selection
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem = newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run { isSendingImage = true }
                    await chatManager.sendImage(data: data, to: partnerId, tradeId: trade.id)
                    await MainActor.run {
                        isSendingImage = false
                        selectedPhotoItem = nil
                        showAttachmentOptions = false
                    }
                }
            }
        }
        .onChange(of: selectedCameraImage) { newImage in
            if let image = newImage, let data = image.jpegData(compressionQuality: 0.7) {
                Task {
                    await MainActor.run { isSendingImage = true }
                    await chatManager.sendImage(data: data, to: partnerId, tradeId: trade.id)
                    await MainActor.run {
                        isSendingImage = false
                        selectedCameraImage = nil
                        showAttachmentOptions = false
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Header
    
    var customHeader: some View {
        HStack(spacing: 16) {
            // Back Button
            Button(action: { dismiss() }) {
                GlassNavButton(icon: "arrow.left")
            }
            
            // Title / Partner Name
            VStack(alignment: .leading, spacing: 2) {
                Text(partnerName)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(chatManager.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(chatManager.isConnected ? "Online" : "Connecting...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                // Action: Complete Trade (Only if Accepted)
                if trade.status == "accepted" {
                    Button {
                        sendCompletionRequest()
                    } label: {
                        if isCompletingTrade {
                            ProgressView().tint(.cyan)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.cyan)
                                .frame(width: 44, height: 44)
                                .background(Color.cyan.opacity(0.1))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .disabled(isCompletingTrade)
                }
                
                // Action: Context Menu
                Menu {
                    Button(role: .destructive, action: { showBlockAlert = true }) {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }
                    Button(action: { showReportAlert = true }) {
                        Label("Report User", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .padding(.top, 60)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.1)), alignment: .bottom)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 5)
    }
    
    // MARK: - Message List Section
    
    private var messageListSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 10)
                    
                    let sections = groupedMessages
                    
                    if sections.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.1))
                            Text("This is the start of your conversation.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.top, 60)
                    }
                    
                    ForEach(sections, id: \.date) { section in
                        Section(header: DateHeader(date: section.date)) {
                            ForEach(section.messages, id: \.id) { message in
                                
                                // SYSTEM MESSAGE
                                if message.content.hasPrefix("ACTION:") {
                                    TradeActionBubble(
                                        message: message,
                                        isMine: message.senderId == myId,
                                        onConfirm: { confirmTradeCompletion() }
                                    )
                                    .id(message.id)
                                    .padding(.bottom, 12)
                                    
                                } else {
                                    // STANDARD MESSAGE
                                    MessageBubble(message: message, isCurrentUser: message.senderId == myId)
                                        .id(message.id)
                                        .padding(.bottom, 12)
                                }
                            }
                        }
                    }
                    
                    if isSendingImage {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .padding(.horizontal)
                        .id("uploading")
                    }
                    
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                withAnimation(.spring()) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                // Scroll to bottom on load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
    
    // MARK: - Logic & Helpers
    
    struct MessageSection: Hashable {
        let date: Date
        let messages: [Message]
    }
    
    var groupedMessages: [MessageSection] {
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
    
    func sendCompletionRequest() {
        Haptics.shared.playMedium()
        Task {
            // Sends a hidden system code
            await chatManager.sendSystemMessage("COMPLETE_REQUEST", to: partnerId, tradeId: trade.id)
        }
    }
    
    func confirmTradeCompletion() {
        Haptics.shared.playSuccess()
        Task {
            // Actual DB Update
            let success = await TradeManager.shared.completeTrade(with: partnerId)
            if success {
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showCompletionCelebration = true
                    }
                }
            } else {
                Haptics.shared.playError()
            }
        }
    }
    
    func fetchPartnerProfile() {
        // Optimized: Check if TradeManager already has it cached
        if let cached = tradeManager.relatedProfiles[partnerId] {
            self.partnerName = cached.username
            return
        }
        
        // Fallback fetch
        Task {
            if let profile = try? await DatabaseService.shared.fetchProfile(userId: partnerId) {
                await MainActor.run { self.partnerName = profile.username }
            }
        }
    }
    
    func reportUser(id: UUID, reason: String) {
        guard let myId = myId else { return }
        Task {
            try? await DatabaseService.shared.reportUser(reporterId: myId, reportedId: id, reason: reason)
        }
    }
    
    func getCoordinate(for item: TradeItem?) -> CLLocationCoordinate2D? {
        guard let lat = item?.latitude, let lon = item?.longitude,
              lat != 0, lon != 0,
              !lat.isNaN, !lon.isNaN else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - UI COMPONENTS

// 1. DATE HEADER
struct DateHeader: View {
    let date: Date
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
    
    var body: some View {
        Text(dateFormatter.string(from: date))
            .font(.caption.bold())
            .foregroundStyle(.white.opacity(0.4))
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
    }
}

// 2. DEAL DASHBOARD (Collapsible)
struct DealDashboard: View {
    let trade: TradeOffer
    @Binding var isExpanded: Bool
    let currentUserId: UUID?
    var onCounter: () -> Void
    
    var iAmSender: Bool { trade.senderId == currentUserId }
    var myItems: [TradeItem] { iAmSender ? trade.allOfferedItems : trade.allWantedItems }
    var theirItems: [TradeItem] { iAmSender ? trade.allWantedItems : trade.allOfferedItems }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Toggle
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundStyle(.cyan)
                    Text(isExpanded ? "Current Deal Details" : "Show Deal Details")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    if !isExpanded {
                        Text("\(theirItems.count) for \(myItems.count)")
                            .font(.caption2.bold())
                            .foregroundStyle(.gray)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            
            // Expanded Content
            if isExpanded {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 0) {
                        // Left Side (Getting)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOU GET (\(theirItems.count))")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.cyan)
                                .padding(.leading, 8)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if theirItems.isEmpty {
                                        Text("None").font(.caption2).foregroundStyle(.gray).padding(8)
                                    } else {
                                        ForEach(theirItems) { item in MiniItemPill(item: item) }
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Center Arrow
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(.white.opacity(0.2))
                            .font(.title3)
                            .padding(.top, 24)
                        
                        // Right Side (Giving)
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("YOU GIVE (\(myItems.count))")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.purple)
                                .padding(.trailing, 8)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if myItems.isEmpty {
                                        Text("None").font(.caption2).foregroundStyle(.gray).padding(8)
                                    } else {
                                        ForEach(myItems) { item in MiniItemPill(item: item) }
                                    }
                                }
                                .padding(.horizontal, 8)
                            }
                            // Force RTL layout for this scrollview so it starts from right
                            .flipsForRightToLeftLayoutDirection(true)
                            .environment(\.layoutDirection, .rightToLeft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 16)
                    
                    // Status / Actions
                    if trade.status == "pending" {
                        if trade.receiverId == currentUserId {
                            Button(action: onCounter) {
                                Text("Propose Counter Offer")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                                    .foregroundStyle(.white)
                            }
                            .padding(.bottom, 12)
                        } else {
                            Text("Waiting for partner response...")
                                .font(.caption2)
                                .italic()
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.bottom, 12)
                        }
                    } else {
                        HStack(spacing: 6) {
                            StatusPillSmall(status: trade.status)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .background(Color.black.opacity(0.2))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.1)), alignment: .bottom)
            }
        }
        .background(.ultraThinMaterial)
    }
}

struct MiniItemPill: View {
    let item: TradeItem
    var body: some View {
        VStack(spacing: 4) {
            AsyncImageView(filename: item.imageUrl)
                .scaledToFill()
                .frame(width: 44, height: 44)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            
            Text(item.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(width: 44)
        }
    }
}

// 3. INPUT BAR
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
            // Attachment Menu
            if showOptions {
                HStack(spacing: 20) {
                    // Safe Zone
                    Button(action: { onMapTap(); withAnimation { showOptions = false } }) {
                        VStack(spacing: 4) {
                            Circle().fill(Color.green.opacity(0.2)).frame(width: 44, height: 44)
                                .overlay(Image(systemName: "checkmark.shield.fill").foregroundStyle(.green))
                            Text("Safe Zone").font(.caption2).foregroundStyle(.white)
                        }
                    }
                    
                    // Camera
                    Button(action: { onCameraTap(); withAnimation { if isPremium { showOptions = false } } }) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.2)).frame(width: 44, height: 44)
                                Image(systemName: "camera.fill").foregroundStyle(.blue)
                                if !isPremium { Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.yellow).offset(x: 14, y: -14) }
                            }
                            Text("Camera").font(.caption2).foregroundStyle(.white)
                        }
                    }
                    
                    // Gallery
                    if isPremium {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            VStack(spacing: 4) {
                                Circle().fill(Color.purple.opacity(0.2)).frame(width: 44, height: 44)
                                    .overlay(Image(systemName: "photo.on.rectangle").foregroundStyle(.purple))
                                Text("Gallery").font(.caption2).foregroundStyle(.white)
                            }
                        }
                    } else {
                        Button(action: onPhotoTap) { // Triggers paywall via logic in parent
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle().fill(Color.purple.opacity(0.2)).frame(width: 44, height: 44)
                                    Image(systemName: "photo.on.rectangle").foregroundStyle(.purple)
                                    Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.yellow).offset(x: 14, y: -14)
                                }
                                Text("Gallery").font(.caption2).foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.leading, 16)
                .padding(.bottom, 8)
                .transition(.scale(scale: 0.8, anchor: .bottomLeading).combined(with: .opacity))
            }
            
            // Text Field Row
            HStack(alignment: .bottom, spacing: 12) {
                Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showOptions.toggle() } }) {
                    Image(systemName: showOptions ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(showOptions ? .white.opacity(0.5) : .cyan)
                        .background(Color.black.clipShape(Circle()))
                }
                .padding(.bottom, 4)
                
                TextField("Message...", text: $text, axis: .vertical)
                    .font(.body)
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                    .foregroundStyle(.white)
                    .lineLimit(1...5)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.2), lineWidth: 1))
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(text.isEmpty ? .gray : .cyan)
                        .background(Color.black.clipShape(Circle()))
                        .shadow(color: text.isEmpty ? .clear : .cyan.opacity(0.3), radius: 5)
                }
                .disabled(text.isEmpty)
                .padding(.bottom, 2)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }
}

// 4. MESSAGE BUBBLE
struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Image
                if let imageUrl = message.imageUrl {
                    AsyncImageView(filename: imageUrl) // ✨ Cached Image
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                
                // Text Content
                if !message.content.isEmpty && message.content != "Sent an image" {
                    if message.content.contains("📍 Let's meet at") {
                        // Special Rendering for Location
                        HStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PROPOSED MEETUP")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.green)
                                Text(message.content.replacingOccurrences(of: "📍 ", with: ""))
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.5), lineWidth: 1))
                        
                    } else {
                        // Standard Text
                        Text(message.content)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isCurrentUser ? Color.cyan : Color.white.opacity(0.15))
                            .foregroundStyle(isCurrentUser ? .black : .white)
                            .clipShape(UnevenRoundedRectangle(
                                topLeadingRadius: 18,
                                bottomLeadingRadius: isCurrentUser ? 18 : 2,
                                bottomTrailingRadius: isCurrentUser ? 2 : 18,
                                topTrailingRadius: 18
                            ))
                    }
                }
                
                // Timestamp
                Text(message.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 4)
            }
            
            if !isCurrentUser { Spacer() }
        }
    }
}
