import SwiftUI

/// AMI-44 (iOS): client list with searchable list and an add sheet.
struct ClientListView: View {
    @State private var vm = ClientListViewModel()
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.clients.isEmpty && !vm.isLoading {
                    if let error = vm.error {
                        ErrorStateView(message: error) { Task { await vm.refresh() } }
                            .padding()
                    } else {
                        EmptyClients()
                    }
                } else {
                    List(vm.clients) { client in
                        NavigationLink(value: client) {
                            ClientRow(client: client)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            // Non-blocking banner for refresh failures when a list is already
            // shown; the full ErrorStateView covers the empty case above.
            .overlay {
                if let error = vm.error, !vm.clients.isEmpty { ErrorBanner(message: error) }
            }
            .searchable(text: $vm.search, prompt: "이름 또는 이메일 검색")
            .onSubmit(of: .search) { Task { await vm.refresh() } }
            .refreshable { await vm.refresh() }
            .task { await vm.refresh() }
            .navigationTitle("고객")
            .navigationDestination(for: ClientDTO.self) { client in
                ClientDetailView(client: client)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("고객 추가")
                }
            }
            .sheet(isPresented: $showAdd) {
                ClientFormView(
                    title: "고객 추가",
                    saveLabel: "저장",
                    error: vm.error,
                    isBusy: vm.isCreating,
                    save: { name, email, phone, company in
                        await vm.create(name: name, email: email, phone: phone, company: company)
                    }
                )
            }
        }
    }
}

private struct ClientRow: View {
    let client: ClientDTO
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(client.name).appFont(.headline)
            if let company = client.company, !company.isEmpty {
                Text(company).appFont(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
            }
            if let email = client.email, !email.isEmpty {
                Text(email).appFont(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyClients: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.2").font(.largeTitle).foregroundStyle(AppColor.baseContent.opacity(0.2))
            Text("아직 고객이 없습니다").appFont(.bodyText)
            Text("+ 버튼으로 첫 고객을 추가하세요.")
                .appFont(.caption).foregroundStyle(AppColor.baseContent.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

