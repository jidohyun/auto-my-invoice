import Foundation

/// AMI-41 / AMI-44 (iOS): local notification preferences.
///
/// The backend `User` schema currently has no per-category notification flags
/// (see `accounts/user.ex`), so these toggles are persisted in UserDefaults
/// and gate whether we register for / honor remote pushes on this device. When
/// the server grows notification preference fields, these can be lifted into
/// the `/settings` payload.
@MainActor
final class NotificationPreferences {
    static let shared = NotificationPreferences()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let pushEnabled = "notif.pushEnabled"
        static let reminderDue = "notif.reminderDue"
        static let paymentReceived = "notif.paymentReceived"
    }

    private init() {
        // Default everything on for first launch.
        if defaults.object(forKey: Key.pushEnabled) == nil {
            defaults.set(true, forKey: Key.pushEnabled)
            defaults.set(true, forKey: Key.reminderDue)
            defaults.set(true, forKey: Key.paymentReceived)
        }
    }

    var pushEnabled: Bool {
        get { defaults.bool(forKey: Key.pushEnabled) }
        set { defaults.set(newValue, forKey: Key.pushEnabled) }
    }

    var reminderDueEnabled: Bool {
        get { defaults.bool(forKey: Key.reminderDue) }
        set { defaults.set(newValue, forKey: Key.reminderDue) }
    }

    var paymentReceivedEnabled: Bool {
        get { defaults.bool(forKey: Key.paymentReceived) }
        set { defaults.set(newValue, forKey: Key.paymentReceived) }
    }
}
