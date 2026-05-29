//
//  InVoiceFlow_iOSApp.swift
//  InVoiceFlow_iOS
//
//  Created by 하동건 on 3/11/26.
//

import SwiftUI
import UIKit

@main
struct InVoiceFlow_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var auth = AuthViewModel()

    init() {
        // Wire baseURL to a build setting if we're shipping; default for
        // the simulator is the Phoenix dev server.
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: urlString) {
            APIClient.shared.baseURL = url
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .task {
                    auth.bootstrap()
                    // AMI-41: register for APNs after launch. Gated on the
                    // user's push preference inside PushManager.
                    await PushManager.shared.registerIfEnabled()
                }
        }
    }
}

/// AMI-41 (iOS): UIKit app delegate, bridged into SwiftUI via
/// `UIApplicationDelegateAdaptor`, purely to receive the APNs remote-token
/// callbacks (SwiftUI's `App` has no hook for these). Token handling is
/// delegated to `PushManager`, which POSTs to `/api/v1/devices`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushManager.shared.didRegister(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushManager.shared.didFailToRegister(error: error)
        }
    }
}
