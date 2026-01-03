import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    @Published var userLocation: CLLocation?
    @Published var permissionStatus: CLAuthorizationStatus
    
    override init() {
        // FIX: Initialize properties BEFORE super.init() to satisfy the compiler
        self.permissionStatus = .notDetermined
        self.userLocation = nil
        
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Delegate Methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.permissionStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location
    }
    
    // MARK: - Helper Methods
    
    /// Calculate distance from user to a target coordinate (in km)
    func distanceFromUser(latitude: Double, longitude: Double) -> Double {
        guard let userLoc = userLocation else { return 0.0 }
        let targetLoc = CLLocation(latitude: latitude, longitude: longitude)
        return userLoc.distance(from: targetLoc) / 1000.0 // Convert meters to km
    }
}
