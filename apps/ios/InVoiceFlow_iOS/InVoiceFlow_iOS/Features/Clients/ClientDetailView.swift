import SwiftUI

/// AMI-44 (iOS): client detail. Shows contact info and a roll-up of the
/// client's invoices (total / outstanding / paid), with an Edit entry point
/// that opens the shared `ClientFormView` bound to `PUT /clients/:id`.
struct ClientDetailView: View {
    @State private var vm: ClientDetailViewModel
    @State private var showEdit = false

    init(client: ClientDTO) {
        _vm = State(initialValue: ClientDetailViewModel(client: client))
    }

    init(clientId: String) {
        _vm = State(initialValue: ClientDetailViewModel(clientId: clientId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let client = vm.client {
                    header(client)
                    countsSection
                    contactSection(client)
                } else if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if let error = vm.error {
                    ErrorStateView(message: error) { Task { await vm.load() } }
                        .padding(.top, 40)
                }

                // Inline error once content is already shown (e.g. invoice
                // count fetch failed but the client decoded).
                if vm.client != nil, let error = vm.error {
                    Text(error)
                        .font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 8))
                }
            }
            .padding(16)
        }
        .navigationTitle(vm.client?.name ?? "고객")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("편집") { showEdit = true }
                    .disabled(vm.client == nil)
            }
        }
        .task { await vm.load() }
        .sheet(isPresented: $showEdit) {
            ClientFormView(
                title: "고객 편집",
                saveLabel: "저장",
                initial: vm.client,
                error: vm.error,
                isBusy: vm.isSaving,
                save: { name, email, phone, company in
                    await vm.update(name: name, email: email, phone: phone, company: company)
                }
            )
        }
    }

    private func header(_ client: ClientDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(client.name).font(.title2.bold())
            if let company = client.company, !company.isEmpty {
                Label(company, systemImage: "building.2")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private var countsSection: some View {
        HStack(spacing: 12) {
            CountTile(value: vm.invoiceCount, label: "송장", system: "doc.text")
            CountTile(value: vm.outstandingCount, label: "미수금", system: "clock", tint: .orange)
            CountTile(value: vm.paidCount, label: "결제완료", system: "checkmark.circle", tint: .green)
        }
    }

    private func contactSection(_ client: ClientDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연락처").font(.headline)
            ContactRow(system: "envelope", value: client.email, placeholder: "이메일 없음")
            ContactRow(system: "phone", value: client.phone, placeholder: "전화번호 없음")
            if let address = client.address, !address.isEmpty {
                ContactRow(system: "mappin.and.ellipse", value: address, placeholder: "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }
}

private struct CountTile: View {
    let value: Int
    let label: String
    let system: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: system).font(.title3).foregroundStyle(tint)
            Text("\(value)").font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
    }
}

private struct ContactRow: View {
    let system: String
    let value: String?
    let placeholder: String

    var body: some View {
        if let value, !value.isEmpty {
            Label(value, systemImage: system).font(.body)
        } else if !placeholder.isEmpty {
            Label(placeholder, systemImage: system)
                .font(.body).foregroundStyle(.secondary)
        }
    }
}
