//
//  DiscoverView.swift
//  LiquidSwap
//
//  Created by Shwetang Mahudkar on 2025-12-26.
//


import SwiftUI
import MapKit

struct DiscoverView: View {
    @StateObject var feedManager = FeedManager()
    
    // State for Detail View Navigation
    @State private var selectedDetailItem: TradeItem?
    
    // Initial Map Position (Toronto Default)
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    ))
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. Theme Background
                LiquidBackground()
                
                VStack(spacing: 0) {
                    // --- HEADER ---
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.cyan)
                            .font(.title2)
                        Text("Discover")
                            .font(.title2).bold()
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Loading Indicator
                        if feedManager.isLoading {
                            ProgressView().tint(.white)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .zIndex(10)
                    
                    // --- MAP CONTENT ---
                    Map(position: $position) {
                        ForEach(feedManager.items) { item in
                            Annotation(item.title, coordinate: CLLocationCoordinate2D(
                                latitude: item.latitude ?? 0.0,
                                longitude: item.longitude ?? 0.0
                            )) {
                                Button(action: { selectedDetailItem = item }) {
                                    VStack(spacing: 0) {
                                        AsyncImageView(filename: item.imageUrl)
                                            .frame(width: 40, height: 40)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.cyan, lineWidth: 2))
                                            .shadow(radius: 4)
                                        
                                        Image(systemName: "triangle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.cyan)
                                            .rotationEffect(.degrees(180))
                                            .offset(y: -4)
                                    }
                                }
                            }
                        }
                    }
                    .edgesIgnoringSafeArea(.bottom)
                }
            }
            .onAppear {
                Task {
                    await feedManager.fetchFeed()
                    // Center map on first item if available
                    if let first = feedManager.items.first {
                        position = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(
                                latitude: first.latitude ?? 43.6532,
                                longitude: first.longitude ?? -79.3832
                            ),
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        ))
                    }
                }
            }
            // Detail Sheet
            .fullScreenCover(item: $selectedDetailItem) { item in
                ProductDetailView(item: item)
            }
        }
    }
}