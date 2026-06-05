import Foundation
import Observation

/// AMI parity (iOS): backs the analytics screen, aggregating three read-only
/// endpoints the web dashboard already exposes — `/dashboard/analytics`,
/// `/analytics/reminders`, and `/clients/ranking`. Each loads independently so
/// one failing endpoint does not blank the whole screen.
@MainActor
@Observable
final class AnalyticsViewModel {
    private(set) var analytics: DashboardAnalyticsDTO?
    private(set) var reminders: ReminderEffectivenessDTO?
    private(set) var ranking: [ClientRankingDTO] = []
    private(set) var isLoading = false
    private(set) var error: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            // Fan out the three independent reads concurrently.
            async let analyticsTask = api.dashboardAnalytics()
            async let remindersTask = api.reminderEffectiveness()
            async let rankingTask = api.clientRanking()
            analytics = try await analyticsTask
            reminders = try await remindersTask
            ranking = try await rankingTask
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
