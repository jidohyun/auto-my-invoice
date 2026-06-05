import Foundation
import UIKit
import UserNotifications

/// AMI-41 (iOS): app-level APNs registration.
///
/// Responsibilities:
/// 1. Request notification authorization via `UNUserNotificationCenter`.
/// 2. Call `registerForRemoteNotifications()` on the main actor.
/// 3. Receive the device token in the `AppDelegate` callback, hex-encode it,
///    and POST it to `/api/v1/devices` as `{token, platform: "ios"}`.
///
/// The backend `/api/v1/devices` route is not deployed yet (server-side task),
/// so a 404/transport failure here is logged and swallowed — push setup must
/// never crash or block the user. Once the route ships this works unchanged.
@MainActor
final class PushManager: NSObject {
    static let shared = PushManager()

    private let api: APIClient
    private let prefs: NotificationPreferences

    private override init() {
        self.api = .shared
        self.prefs = .shared
        super.init()
    }

    /// Requests authorization (if push is enabled in preferences) and, on
    /// grant, kicks off remote registration. Safe to call on every launch and
    /// after the user toggles push back on.
    func registerIfEnabled() async {
        guard prefs.pushEnabled else { return }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            #if DEBUG
            print("[PushManager] authorization failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Called from the `AppDelegate` APNs success callback. Hex-encodes the
    /// raw token and forwards it to the backend.
    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await sendToken(token) }
    }

    func didFailToRegister(error: Error) {
        #if DEBUG
        print("[PushManager] APNs registration failed: \(error.localizedDescription)")
        #endif
    }

    private func sendToken(_ token: String) async {
        do {
            try await api.registerDevice(token: token)
        } catch {
            // Expected until the /devices route ships server-side. Log only.
            #if DEBUG
            print("[PushManager] device token POST failed (route pending?): \(error.localizedDescription)")
            #endif
        }
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    /// Show banners/sounds even when the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
