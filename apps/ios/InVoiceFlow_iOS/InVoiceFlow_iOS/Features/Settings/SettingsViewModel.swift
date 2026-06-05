import Foundation
import Observation

/// AMI-44 (iOS): settings screen.
///
/// Profile fields are loaded from `GET /api/v1/settings` (which renders the
/// user via `JsonHelpers.render_user/1`) and saved with `PUT /api/v1/settings`
/// (wrapped under `settings`, accepting the `profile_changeset` fields:
/// company_name, default_currency, payment_terms, brand_tone, invoice_prefix,
/// business_address, business_registration_number).
///
/// Note: `render_user` does not echo back default_currency/payment_terms/
/// invoice_prefix, so those start from sensible defaults and are write-only
/// from this screen until the backend renderer is extended.
@MainActor
@Observable
final class SettingsViewModel {
    private(set) var settings: UserSettingsDTO?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var error: String?
    private(set) var saveConfirmation = false

    // Editable profile fields.
    var companyName = ""
    var defaultCurrency = "KRW"
    var paymentTerms = 30
    var invoicePrefix = "INV"

    // Local-only notification toggles (no backend field yet — see PushManager).
    var pushEnabled: Bool {
        didSet { prefs.pushEnabled = pushEnabled }
    }
    var reminderDueEnabled: Bool {
        didSet { prefs.reminderDueEnabled = reminderDueEnabled }
    }
    var paymentReceivedEnabled: Bool {
        didSet { prefs.paymentReceivedEnabled = paymentReceivedEnabled }
    }

    let currencies = ["KRW", "USD", "EUR", "JPY", "GBP"]
    let paymentTermsOptions = [15, 30, 45, 60]

    private let api: APIClient
    private let prefs: NotificationPreferences

    init(api: APIClient = .shared, prefs: NotificationPreferences = .shared) {
        self.api = api
        self.prefs = prefs
        self.pushEnabled = prefs.pushEnabled
        self.reminderDueEnabled = prefs.reminderDueEnabled
        self.paymentReceivedEnabled = prefs.paymentReceivedEnabled
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let dto = try await api.settings()
            settings = dto
            companyName = dto.companyName ?? ""
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        saveConfirmation = false
        defer { isSaving = false }

        let body = UserSettingsUpdate(
            companyName: companyName.isEmpty ? nil : companyName,
            defaultCurrency: defaultCurrency,
            paymentTerms: paymentTerms,
            brandTone: nil,
            businessAddress: nil,
            businessRegistrationNumber: nil,
            invoicePrefix: invoicePrefix.isEmpty ? nil : invoicePrefix
        )

        do {
            settings = try await api.updateSettings(body)
            saveConfirmation = true
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
