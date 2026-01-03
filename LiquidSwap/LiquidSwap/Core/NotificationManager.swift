import SwiftUI
import UserNotifications
import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    override private init() { // Private init ensures it's a true Singleton
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // 1. Request Permission
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .authorized : .denied
                print("🔔 Notification Permission: \(granted ? "Granted" : "Denied")")
            }
        }
    }
    
    // 2. Trigger a "Local" Push
    func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Show immediately (0.1s delay)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // 3. Handle Foreground Notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // ✨ FIX: Return empty array [] to suppress banners while app is open.
        // The app's UI (ChatRoomView) already updates automatically via Realtime.
        completionHandler([])
    }
}
