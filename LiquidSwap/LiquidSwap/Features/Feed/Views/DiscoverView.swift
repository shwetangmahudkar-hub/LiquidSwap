import SwiftUI
import MapKit

// MARK: - Models

struct RecyclingPoint: Identifiable {
    let id = UUID()
    let name: String
    let type: RecyclingType
    let coordinate: CLLocationCoordinate2D
    let address: String
    let mapItem: MKMapItem
    
    enum RecyclingType: String, CaseIterable {
        case general = "General"
        case batteries = "Batteries"
        case electronics = "E-Waste"
        case clothing = "Textiles"
        case glass = "Glass"
        
        var icon: String {
            switch self {
            case .general: return "trash.slash.fill"
            case .batteries: return "bolt.batteryblock.fill"
            case .electronics: return "desktopcomputer"
            case .clothing: return "tshirt.fill"
            case .glass: return "wineglass.fill"
            }
        }
        
        var color: UIColor {
            switch self {
            case .general: return .systemGreen
            case .batteries: return .systemOrange
            case .electronics: return .systemBlue
            case .clothing: return .systemPink
            case .glass: return .systemTeal
            }
        }
    }
}

struct SafeZone: Identifiable {
    let id = UUID()
    let name: String
    let type: ZoneType
    let coordinate: CLLocationCoordinate2D
    let address: String
    let mapItem: MKMapItem
    
    enum ZoneType: String, CaseIterable {
        case police = "Police Station"
        case publicPlace = "Public Plaza"
        case monitored = "Safe Exchange"
        
        var icon: String {
            switch self {
            case .police: return "shield.lefthalf.filled"
            case .publicPlace: return "building.columns.fill"
            case .monitored: return "video.fill"
            }
        }
        
        var color: UIColor {
            switch self {
            case .police: return .systemBlue
            case .publicPlace: return .systemPurple
            case .monitored: return .systemOrange
            }
        }
    }
}

struct RepairService: Identifiable {
    let id = UUID()
    let name: String
    let type: RepairType
    let coordinate: CLLocationCoordinate2D
    let address: String
    let mapItem: MKMapItem
    
    enum RepairType: String, CaseIterable {
        case tailor = "Tailor"
        case cobbler = "Shoe Repair"
        case electronics = "Tech Repair"
        case bike = "Bike Shop"
        case general = "General Fix"
        
        var icon: String {
            switch self {
            case .tailor: return "scissors"
            case .cobbler: return "shoeprints.fill"
            case .electronics: return "screwdriver.fill"
            case .bike: return "bicycle"
            case .general: return "wrench.and.screwdriver.fill"
            }
        }
        
        var color: UIColor {
            switch self {
            case .tailor: return .systemPurple
            case .cobbler: return .systemBrown
            case .electronics: return .systemIndigo
            case .bike: return .systemRed
            case .general: return .systemGray
            }
        }
    }
}

struct DiscoverView: View {
    @ObservedObject var feedManager = FeedManager.shared
    @StateObject var locationManager = LocationManager.shared
    
    // Navigation State
    @State private var selectedDetailItem: TradeItem?
    @State private var selectedRecyclingPoint: RecyclingPoint?
    @State private var selectedSafeZone: SafeZone?
    @State private var selectedRepairService: RepairService?
    
    // Search State
    @State private var isSearching = false
    @State private var lastSearchedRegion: MKCoordinateRegion?
    @State private var searchTask: Task<Void, Never>?
    
    // Live Data Containers
    @State private var liveRecyclingPoints: [RecyclingPoint] = []
    @State private var liveSafeZones: [SafeZone] = []
    @State private var liveRepairServices: [RepairService] = []
    
    // Filter State
    enum MapMode { case trades, recycling, safety, repair }
    @State private var mapMode: MapMode = .trades
    @State private var activeRecyclingFilter: RecyclingPoint.RecyclingType? = nil
    @State private var activeRepairFilter: RepairService.RepairType? = nil
    
    // Computed Filtered Lists
    var visibleRecyclingPoints: [RecyclingPoint] {
        guard let filter = activeRecyclingFilter else { return liveRecyclingPoints }
        return liveRecyclingPoints.filter { $0.type == filter }
    }
    
    var visibleRepairServices: [RepairService] {
        guard let filter = activeRepairFilter else { return liveRepairServices }
        return liveRepairServices.filter { $0.type == filter }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                
                // 1. MAP LAYER (Unified Clustered Map + 3D Cinematic)
                ClusteredMapView(
                    mapMode: mapMode,
                    items: feedManager.items,
                    recyclingPoints: visibleRecyclingPoints,
                    safeZones: liveSafeZones,
                    repairServices: visibleRepairServices,
                    onRegionChange: { region in
                        performSearch(region: region)
                    },
                    onSelectItem: { selectedDetailItem = $0 },
                    onSelectRecycling: { selectedRecyclingPoint = $0 },
                    onSelectSafeZone: { selectedSafeZone = $0 },
                    onSelectRepair: { selectedRepairService = $0 }
                )
                .ignoresSafeArea()
                
                // 2. HEADER: Floating "Island" Pill
                VStack(spacing: 8) {
                    
                    // THE MAIN CAPSULE
                    HStack(spacing: 10) {
                        // Title Section
                        HStack(spacing: 5) {
                            if #available(iOS 17.0, *) {
                                Image(systemName: headerIcon)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.cyan)
                                    .contentTransition(.symbolEffect(.replace))
                                
                                Text(headerTitle)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                            } else {
                                Image(systemName: headerIcon)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.cyan)
                                
                                Text(headerTitle)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        Spacer()
                        
                        if isSearching {
                            ProgressView().tint(.white).scaleEffect(0.6)
                        }
                        
                        // Compact Toggle Divider
                        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
                        
                        // Mode Toggles
                        HStack(spacing: 0) {
                            ModeButton(icon: "cube.box.fill", isSelected: mapMode == .trades) {
                                withAnimation { mapMode = .trades }
                            }
                            ModeButton(icon: "leaf.fill", isSelected: mapMode == .recycling) {
                                withAnimation { mapMode = .recycling }
                            }
                            ModeButton(icon: "wrench.and.screwdriver.fill", isSelected: mapMode == .repair) {
                                withAnimation { mapMode = .repair }
                            }
                            ModeButton(icon: "shield.fill", isSelected: mapMode == .safety) {
                                withAnimation { mapMode = .safety }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    // Floating Shadow
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.top, 56)
                    
                    // SECONDARY PILL: Micro Filters
                    if mapMode == .recycling || mapMode == .repair {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                if mapMode == .recycling {
                                    FilterChip(title: "All", icon: "square.grid.2x2.fill", isSelected: activeRecyclingFilter == nil) { withAnimation { activeRecyclingFilter = nil } }
                                    ForEach(RecyclingPoint.RecyclingType.allCases, id: \.self) { type in
                                        FilterChip(title: type.rawValue, icon: type.icon, isSelected: activeRecyclingFilter == type) { withAnimation { activeRecyclingFilter = type } }
                                    }
                                } else {
                                    FilterChip(title: "All", icon: "square.grid.2x2.fill", isSelected: activeRepairFilter == nil) { withAnimation { activeRepairFilter = nil } }
                                    ForEach(RepairService.RepairType.allCases, id: \.self) { type in
                                        FilterChip(title: type.rawValue, icon: type.icon, isSelected: activeRepairFilter == type) { withAnimation { activeRepairFilter = type } }
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                        }
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 4)
                        .padding(.horizontal, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                // 3. Search Button (Bottom Floating)
                if mapMode != .trades && !isSearching {
                    VStack {
                        Spacer()
                        Button(action: {
                            if let region = lastSearchedRegion { performSearch(region: region) }
                        }) {
                            Label("Search This Area", systemImage: "arrow.clockwise")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .shadow(radius: 4)
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await feedManager.fetchFeed()
                }
            }
            // Sheets
            .sheet(item: $selectedDetailItem) { item in
                NavigationStack {
                    ProductDetailView(item: item)
                }
                .presentationDragIndicator(.visible)
            }
            // Micro Interaction Sheets
            .sheet(item: $selectedRecyclingPoint) { point in RecyclingDetailSheet(point: point).presentationDetents([.height(400), .large]).presentationDragIndicator(.visible) }
            .sheet(item: $selectedSafeZone) { zone in SafeZoneDetailSheet(zone: zone).presentationDetents([.height(400), .large]).presentationDragIndicator(.visible) }
            .sheet(item: $selectedRepairService) { service in RepairDetailSheet(service: service).presentationDetents([.height(400), .large]).presentationDragIndicator(.visible) }
        }
    }
    
    // MARK: - LIVE SEARCH LOGIC (DEBOUNCED)
    
    func performSearch(region: MKCoordinateRegion) {
        guard mapMode != .trades else { return }
        
        searchTask?.cancel()
        lastSearchedRegion = region
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            
            await MainActor.run { self.isSearching = true }
            
            var queries: [String] = []
            switch mapMode {
            case .recycling: queries = ["Recycling Center", "Clothing Donation", "Goodwill", "E-Waste Dropoff"]
            case .repair: queries = ["Tailor", "Shoe Repair", "Electronics Repair", "Bike Shop"]
            case .safety: queries = ["Police Station", "Public Library", "Community Centre"]
            default: break
            }
            
            var newItems: [MKMapItem] = []
            for query in queries {
                if Task.isCancelled { return }
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.region = region
                if let response = try? await MKLocalSearch(request: request).start() {
                    newItems.append(contentsOf: response.mapItems)
                }
            }
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                switch mapMode {
                case .recycling:
                    self.liveRecyclingPoints = newItems.prefix(20).map { item in
                        let name = item.name?.lowercased() ?? ""
                        var type: RecyclingPoint.RecyclingType = .general
                        if name.contains("clothing") || name.contains("goodwill") { type = .clothing }
                        else if name.contains("tech") || name.contains("computer") { type = .electronics }
                        else if name.contains("bottle") { type = .glass }
                        return RecyclingPoint(name: item.name ?? "Recycling", type: type, coordinate: item.placemark.coordinate, address: item.placemark.title ?? "", mapItem: item)
                    }
                case .repair:
                    self.liveRepairServices = newItems.prefix(20).map { item in
                        let name = item.name?.lowercased() ?? ""
                        var type: RepairService.RepairType = .general
                        if name.contains("tailor") || name.contains("sew") { type = .tailor }
                        else if name.contains("shoe") || name.contains("cobbler") { type = .cobbler }
                        else if name.contains("phone") || name.contains("computer") || name.contains("tech") { type = .electronics }
                        else if name.contains("bike") || name.contains("cycle") { type = .bike }
                        return RepairService(name: item.name ?? "Repair Shop", type: type, coordinate: item.placemark.coordinate, address: item.placemark.title ?? "", mapItem: item)
                    }
                case .safety:
                    self.liveSafeZones = newItems.prefix(15).map { item in
                        var type: SafeZone.ZoneType = .publicPlace
                        if item.pointOfInterestCategory == .police { type = .police }
                        return SafeZone(name: item.name ?? "Safe Zone", type: type, coordinate: item.placemark.coordinate, address: item.placemark.title ?? "", mapItem: item)
                    }
                default: break
                }
                self.isSearching = false
            }
        }
    }
    
    // Helpers
    var headerTitle: String {
        switch mapMode {
        case .trades: return "Discover"
        case .recycling: return "Recycle"
        case .safety: return "Safe Zones"
        case .repair: return "Repair"
        }
    }
    
    var headerIcon: String {
        switch mapMode {
        case .trades: return "map.fill"
        case .recycling: return "leaf.fill"
        case .safety: return "shield.fill"
        case .repair: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Clustered Map View (UIKit Wrapper + 3D Camera)

struct ClusteredMapView: UIViewRepresentable {
    let mapMode: DiscoverView.MapMode
    let items: [TradeItem]
    let recyclingPoints: [RecyclingPoint]
    let safeZones: [SafeZone]
    let repairServices: [RepairService]
    
    let onRegionChange: (MKCoordinateRegion) -> Void
    let onSelectItem: (TradeItem) -> Void
    let onSelectRecycling: (RecyclingPoint) -> Void
    let onSelectSafeZone: (SafeZone) -> Void
    let onSelectRepair: (RepairService) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        
        // 1. Enable Realistic Elevation (3D Buildings)
        if #available(iOS 16.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        }
        
        // 2. Register Annotation Views
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "trade")
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "recycling")
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "safety")
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "repair")
        
        // 3. CINEMATIC 3D CAMERA SETUP
        if let userLoc = LocationManager.shared.userLocation {
            let camera = MKMapCamera(
                lookingAtCenter: userLoc.coordinate,
                fromDistance: 1500,
                pitch: 45,
                heading: 0
            )
            mapView.setCamera(camera, animated: false)
        } else {
            let fallbackLoc = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)
            let camera = MKMapCamera(
                lookingAtCenter: fallbackLoc,
                fromDistance: 1500,
                pitch: 45,
                heading: 0
            )
            mapView.setCamera(camera, animated: false)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        let currentAnnotations = mapView.annotations.compactMap { $0 as? UnifiedAnnotation }
        var newAnnotations: [UnifiedAnnotation] = []
        var newOverlays: [MKOverlay] = []
        
        if mapMode == .trades {
            newAnnotations = items.map { UnifiedAnnotation(item: $0) }
            newOverlays = items.compactMap { item in
                guard let lat = item.latitude, let lon = item.longitude else { return nil }
                return MKCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: 500)
            }
        } else if mapMode == .recycling {
            newAnnotations = recyclingPoints.map { UnifiedAnnotation(point: $0) }
        } else if mapMode == .safety {
            newAnnotations = safeZones.map { UnifiedAnnotation(zone: $0) }
        } else if mapMode == .repair {
            newAnnotations = repairServices.map { UnifiedAnnotation(service: $0) }
        }
        
        let currentIDs = Set(currentAnnotations.map { $0.id })
        let newIDs = Set(newAnnotations.map { $0.id })
        
        if currentIDs != newIDs {
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(newAnnotations)
            
            mapView.removeOverlays(mapView.overlays)
            if !newOverlays.isEmpty {
                mapView.addOverlays(newOverlays)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredMapView
        init(parent: ClusteredMapView) { self.parent = parent }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.cyan.withAlphaComponent(0.15)
                renderer.strokeColor = UIColor.cyan.withAlphaComponent(0.5)
                renderer.lineWidth = 1
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? UnifiedAnnotation else { return nil }
            var identifier = "trade"; var clusterID = "trade-cluster"; var glyphImage = "shippingbox.fill"; var color = UIColor.cyan
            
            switch annotation.type {
            case .trade: break
            case .recycling(let p): identifier = "recycling"; clusterID = "recycling-cluster"; glyphImage = p.type.icon; color = p.type.color
            case .safety(let z): identifier = "safety"; clusterID = "safety-cluster"; glyphImage = z.type.icon; color = z.type.color
            case .repair(let r): identifier = "repair"; clusterID = "repair-cluster"; glyphImage = r.type.icon; color = r.type.color
            }
            
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier, for: annotation) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            view.annotation = annotation
            view.markerTintColor = color
            view.glyphImage = UIImage(systemName: glyphImage)
            view.clusteringIdentifier = clusterID
            view.displayPriority = .defaultHigh
            return view
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? UnifiedAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: true)
            switch annotation.type {
            case .trade(let item): parent.onSelectItem(item)
            case .recycling(let point): parent.onSelectRecycling(point)
            case .safety(let zone): parent.onSelectSafeZone(zone)
            case .repair(let service): parent.onSelectRepair(service)
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
        }
    }
}

class UnifiedAnnotation: NSObject, MKAnnotation {
    let id: UUID; let coordinate: CLLocationCoordinate2D; let title: String?; let type: AnnotationType
    enum AnnotationType { case trade(TradeItem); case recycling(RecyclingPoint); case safety(SafeZone); case repair(RepairService) }
    init(item: TradeItem) { self.id = item.id; self.coordinate = CLLocationCoordinate2D(latitude: item.latitude ?? 0, longitude: item.longitude ?? 0); self.title = item.title; self.type = .trade(item) }
    init(point: RecyclingPoint) { self.id = point.id; self.coordinate = point.coordinate; self.title = point.name; self.type = .recycling(point) }
    init(zone: SafeZone) { self.id = zone.id; self.coordinate = zone.coordinate; self.title = zone.name; self.type = .safety(zone) }
    init(service: RepairService) { self.id = service.id; self.coordinate = service.coordinate; self.title = service.name; self.type = .repair(service) }
}

// MARK: - Subviews
struct ModeButton: View {
    let icon: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .padding(8)
                .background(isSelected ? Color.white : Color.clear)
                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                .clipShape(Circle())
        }
    }
}

struct FilterChip: View {
    let title: String; let icon: String; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption2.bold())
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.cyan : Color.white.opacity(0.1))
            .foregroundStyle(isSelected ? .black : .white)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Look Around
struct SafeLookAroundView: View {
    let mapItem: MKMapItem?
    @State private var scene: MKLookAroundScene?
    @State private var hasLookAround: Bool = false
    @State private var isLoading: Bool = true
    
    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.2))
                    ProgressView()
                }
            } else if let scene = scene, hasLookAround {
                if #available(iOS 17.0, *) {
                    LookAroundPreview(initialScene: scene)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                } else {
                    LegacyLookAroundView(scene: scene)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.1))
                    VStack(spacing: 6) {
                        Image(systemName: "eye.slash.fill").font(.title2).foregroundStyle(.white.opacity(0.3))
                        Text("No Preview Available").font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .task(id: mapItem) { await fetchScene() }
    }
    
    private func fetchScene() async {
        guard let mapItem = mapItem else { isLoading = false; return }
        let request = MKLookAroundSceneRequest(mapItem: mapItem)
        do {
            if let s = try await request.scene {
                self.scene = s
                self.hasLookAround = true
            } else {
                self.hasLookAround = false
            }
        } catch {
            self.hasLookAround = false
        }
        withAnimation { self.isLoading = false }
    }
}

struct LegacyLookAroundView: UIViewControllerRepresentable {
    let scene: MKLookAroundScene
    func makeUIViewController(context: Context) -> MKLookAroundViewController { MKLookAroundViewController(scene: scene) }
    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) { uiViewController.scene = scene }
}

// MARK: - Sheets

struct RecyclingDetailSheet: View {
    let point: RecyclingPoint
    var body: some View {
        StandardDetailLayout(icon: point.type.icon, color: Color(uiColor: point.type.color), title: point.name, badge: point.type.rawValue, address: point.address, mapItem: point.mapItem)
    }
}

struct SafeZoneDetailSheet: View {
    let zone: SafeZone
    var body: some View {
        StandardDetailLayout(icon: zone.type.icon, color: Color(uiColor: zone.type.color), title: zone.name, badge: "VERIFIED SAFE", address: zone.address, isVerified: true, mapItem: zone.mapItem)
    }
}

struct RepairDetailSheet: View {
    let service: RepairService
    var body: some View {
        StandardDetailLayout(icon: service.type.icon, color: Color(uiColor: service.type.color), title: service.name, badge: service.type.rawValue, address: service.address, mapItem: service.mapItem)
    }
}

struct StandardDetailLayout: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let icon: String
    let color: Color
    let title: String
    let badge: String
    let address: String
    var isVerified: Bool = false
    let mapItem: MKMapItem?
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8)
    }
    
    var body: some View {
        ZStack {
            LiquidBackground().opacity(0.3)
            
            VStack(spacing: 0) {
                // Handle bar
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 36, height: 4).padding(.top, 8).padding(.bottom, 14)
                
                // 1. Look Around Preview (Hero)
                SafeLookAroundView(mapItem: mapItem)
                    .frame(height: 130)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                
                // 2. Info Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(color.opacity(0.2)).frame(width: 44, height: 44)
                        Image(systemName: icon).font(.title3).foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(title).font(.subheadline.bold()).foregroundStyle(primaryText).lineLimit(1)
                            if isVerified { Image(systemName: "checkmark.seal.fill").foregroundStyle(.cyan) }
                        }
                        Text(badge).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2).background(color.opacity(0.2)).foregroundStyle(color).cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 12)
                
                // 3. Info Rows
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse").foregroundStyle(.gray).frame(width: 18)
                        Text(address).font(.caption).foregroundStyle(secondaryText).lineLimit(1)
                        Spacer()
                    }
                    if let phone = mapItem?.phoneNumber {
                        HStack {
                            Image(systemName: "phone.fill").foregroundStyle(.gray).frame(width: 18)
                            Text(phone).font(.caption).foregroundStyle(secondaryText)
                            Spacer()
                        }
                    }
                    if let url = mapItem?.url {
                        HStack {
                            Image(systemName: "link").foregroundStyle(.gray).frame(width: 18)
                            Text(url.host ?? "Website").font(.caption).foregroundStyle(.cyan).underline()
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // 4. Action Grid
                HStack(spacing: 10) {
                    Button(action: { mapItem?.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]) }) {
                        VStack(spacing: 4) {
                            Image(systemName: "car.fill").font(.subheadline)
                            Text("Go").font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity).frame(height: 52).background(Color.blue).foregroundStyle(.white).cornerRadius(10)
                    }
                    if let phone = mapItem?.phoneNumber {
                        Button(action: { if let url = URL(string: "tel://\(phone.filter{!$0.isWhitespace})") { UIApplication.shared.open(url) } }) {
                            VStack(spacing: 4) {
                                Image(systemName: "phone.fill").font(.subheadline)
                                Text("Call").font(.caption2.bold())
                            }
                            .frame(maxWidth: .infinity).frame(height: 52).background(Color.white.opacity(0.1)).foregroundStyle(.green).cornerRadius(10)
                        }
                    }
                    if let url = mapItem?.url {
                        Button(action: { UIApplication.shared.open(url) }) {
                            VStack(spacing: 4) {
                                Image(systemName: "globe").font(.subheadline)
                                Text("Web").font(.caption2.bold())
                            }
                            .frame(maxWidth: .infinity).frame(height: 52).background(Color.white.opacity(0.1)).foregroundStyle(.cyan).cornerRadius(10)
                        }
                    }
                    Button(action: { mapItem?.openInMaps() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "info.circle").font(.subheadline)
                            Text("More").font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity).frame(height: 52).background(Color.white.opacity(0.1)).foregroundStyle(.gray).cornerRadius(10)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }
}
