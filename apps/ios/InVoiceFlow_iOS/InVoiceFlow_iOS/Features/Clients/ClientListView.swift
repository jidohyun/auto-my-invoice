import SwiftUI

/// AMI-44 (iOS): client list with searchable list and an add sheet.
struct ClientListView: View {
    @State private var vm = ClientListViewModel()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.clients.isEmpty && !vm.isLoading {
                    EmptyClients()
                } else {
                    List(vm.clients) { client in
                        ClientRow(client: client)
                    }
                    .listStyle(.plain)
                }
            }
            .overlay { if let error = vm.error { ErrorBanner(message: error) } }
            .searchable(text: $vm.search, prompt: "이름 또는 이메일 검색")
            .onSubmit(of: .search) { Task { await vm.refresh() } }
            .refreshable { await vm.refresh() }
            .task { await vm.refresh() }
            .navigationTitle("고객")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("고객 추가")
                }
            }
            .sheet(isPresented: $showAdd) {
                ClientCreateView(vm: vm)
            }
        }
    }
}

private struct ClientRow: View {
    let client: ClientDTO
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.name).font(.body.weight(.semibold))
            if let company = client.company, !company.isEmpty {
                Text(company).font(.caption).foregroundStyle(.secondary)
            }
            if let email = client.email, !email.isEmpty {
                Text(email).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyClients: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.2").font(.largeTitle).foregroundStyle(.secondary)
            Text("아직 고객이 없습니다").font(.body)
            Text("+ 버튼으로 첫 고객을 추가하세요.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Add-client form presented as a sheet. Shares the list's view model so the
/// new client lands in the list without a round-trip refresh.
private struct ClientCreateView: View {
    let vm: ClientListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var company = ""

    var body: some View {
        NavigationStack {
            Form {
                if let error = vm.error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
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
            .navigationTitle("고객 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            let ok = await vm.create(
                                name: name,
                                email: email.isEmpty ? nil : email,
                                phone: phone.isEmpty ? nil : phone,
                                company: company.isEmpty ? nil : company
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || vm.isCreating)
                }
            }
        }
    }
}
