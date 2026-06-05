import SwiftUI

/// AMI-44 (iOS): shared client form used for both create (`POST /clients`) and
/// edit (`PUT /clients/:id`). The owner supplies the initial field values, an
/// async `save` closure that performs the network call (returning success),
/// and the live `error`/`isBusy` flags from its view model so the form mirrors
/// the rest of the app's loading + inline-error conventions.
struct ClientFormView: View {
    let title: String
    let saveLabel: String
    let error: String?
    let isBusy: Bool
    /// Returns `true` on success so the form can dismiss itself.
    let save: (_ name: String, _ email: String?, _ phone: String?, _ company: String?) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var company: String

    init(
        title: String,
        saveLabel: String,
        initial: ClientDTO? = nil,
        error: String?,
        isBusy: Bool,
        save: @escaping (_ name: String, _ email: String?, _ phone: String?, _ company: String?) async -> Bool
    ) {
        self.title = title
        self.saveLabel = saveLabel
        self.error = error
        self.isBusy = isBusy
        self.save = save
        _name = State(initialValue: initial?.name ?? "")
        _email = State(initialValue: initial?.email ?? "")
        _phone = State(initialValue: initial?.phone ?? "")
        _company = State(initialValue: initial?.company ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isBusy
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section { Text(error).font(.footnote).foregroundStyle(AppColor.error) }
                }
                Section("필수") {
                    TextField("이름", text: $name)
                }
                Section("선택") {
                    TextField("이메일", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("전화번호", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("회사명", text: $company)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveLabel) {
                        Task {
                            let ok = await save(
                                name,
                                email.isEmpty ? nil : email,
                                phone.isEmpty ? nil : phone,
                                company.isEmpty ? nil : company
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .overlay {
                if isBusy { ProgressView().controlSize(.large) }
            }
        }
    }
}
