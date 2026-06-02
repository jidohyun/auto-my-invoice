import Foundation
import Observation

/// AMI-88 (iOS): app-wide auth state. Holds the current user, drives
/// login/register, and persists the token in Keychain so cold starts
/// stay logged in until the token expires.
@MainActor
@Observable
final class AuthViewModel {
    enum State: Equatable {
        case checking
        case loggedOut
        case loggedIn(AuthUser)
    }

    private(set) var state: State = .checking
    var isSubmitting = false
    var error: String?

    private let api: APIClient
    private let keychain: KeychainStore

    init(api: APIClient = .shared, keychain: KeychainStore = .shared) {
        self.api = api
        self.keychain = keychain
    }

    func bootstrap() async {
        // Presence of a token is not enough — a stale/expired token left from a
        // prior session would otherwise promote us straight to .loggedIn and
        // wedge the app on a dashboard that 401s with "로그인이 필요합니다".
        // Validate it with one lightweight authenticated call before trusting it.
        guard keychain.token() != nil else {
            state = .loggedOut
            return
        }
        do {
            _ = try await api.dashboard()
            // Token is valid; carry a stub user (the real one is unavailable
            // from cold storage) until a screen fetches richer data.
            state = .loggedIn(AuthUser(id: "_pending", email: ""))
        } catch APIError.unauthorized {
            // Stale/invalid token — clear it and fall back to the login screen.
            logOut()
        } catch {
            // Transport/offline failure: don't punish a flaky connection with a
            // forced logout. Stay provisionally logged in; the next successful
            // call confirms us, and a real 401 self-heals via onUnauthorized.
            state = .loggedIn(AuthUser(id: "_pending", email: ""))
        }
    }

    func login(email: String, password: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        do {
            let data = try await api.login(email: email, password: password)
            guard keychain.save(token: data.token) else {
                self.error = "로그인 정보를 저장하지 못했습니다. 다시 시도해 주세요."
                return
            }
            state = .loggedIn(data.user)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func register(email: String, password: String, companyName: String = "") async {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        do {
            let data = try await api.register(
                email: email,
                password: password,
                companyName: companyName.isEmpty ? nil : companyName
            )
            guard keychain.save(token: data.token) else {
                self.error = "로그인 정보를 저장하지 못했습니다. 다시 시도해 주세요."
                return
            }
            state = .loggedIn(data.user)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func logOut() {
        keychain.clear()
        state = .loggedOut
    }
}
