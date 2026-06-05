import SwiftUI
import UIKit

/// Thin `UIActivityViewController` wrapper for sharing/saving files (e.g. the
/// downloaded invoice PDF). Presented from a `.sheet`; `items` are typically
/// file URLs so the system offers "Save to Files", "Mail", "Print", etc.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
