import Foundation
import Observation

/// AMI-44 (iOS): client list backed by `GET /api/v1/clients`, with a search
/// query (`q`) and inline create via `POST /api/v1/clients`. Follows the same
/// `@Observable` MVI shape as the other view models.
@MainActor
@Observable
final class ClientListViewModel {
    private(set) var clients: [ClientDTO] = []
    private(set) var isLoading = false
    private(set) var isCreating = false
    private(set) var error: String?

    var search = ""

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            clients = try await api.clients(search: search)
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Creates a client and prepends it to the list. Returns success so the
    /// view can dismiss the add sheet.
    func create(name: String, email: String?, phone: String?, company: String?) async -> Bool {
        guard !isCreating else { return false }
        isCreating = true
        error = nil
        defer { isCreating = false }
        do {
            let created = try await api.createClient(
                ClientRequest(name: name, email: email, phone: phone, company: company)
            )
            clients = [created] + clients
            return true
        } catch let e as APIError {
            error = e.errorDescription
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
