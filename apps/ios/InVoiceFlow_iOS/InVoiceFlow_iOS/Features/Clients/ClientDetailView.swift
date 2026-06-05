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
                    if let analytics = vm.analytics {
                        analyticsSection(analytics)
                    }
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
                        .font(.footnote).foregroundStyle(AppColor.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppColor.error.opacity(0.1), in: .rect(cornerRadius: AppRadius.field))
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
            Text(client.name).appFont(.displayTitle)
            if let company = client.company, !company.isEmpty {
                Label(company, systemImage: "building.2")
                    .appFont(.callout).foregroundStyle(AppColor.baseContent.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCard()
    }

    private var countsSection: some View {
        HStack(spacing: 12) {
            CountTile(value: vm.invoiceCount, label: "송장", system: "doc.text")
            CountTile(value: vm.outstandingCount, label: "미수금", system: "clock", tint: AppColor.warning)
            CountTile(value: vm.paidCount, label: "결제완료", system: "checkmark.circle", tint: AppColor.success)
        }
    }

    private func contactSection(_ client: ClientDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("연락처").appFont(.headline)
            ContactRow(system: "envelope", value: client.email, placeholder: "이메일 없음")
            ContactRow(system: "phone", value: client.phone, placeholder: "전화번호 없음")
            if let address = client.address, !address.isEmpty {
                ContactRow(system: "mappin.and.ellipse", value: address, placeholder: "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCard()
    }

    /// Server-computed payment behaviour for this client (`/clients/:id/analytics`).
    /// All money fields are KRW-rolled (AMI-90).
    private func analyticsSection(_ a: ClientAnalyticsDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("결제 분석").appFont(.headline)
            analyticsRow("총 청구액", MoneyFormatter.format(a.totalInvoiced, currency: "KRW"))
            analyticsRow("총 수금액", MoneyFormatter.format(a.totalPaid, currency: "KRW"))
            analyticsRow("미수금", MoneyFormatter.format(a.outstandingAmount, currency: "KRW"))
            if let days = a.avgPaymentDays {
                analyticsRow("평균 결제 소요", String(format: "%.0f일", days))
            }
            if let rate = a.onTimeRate {
                analyticsRow("정시 결제율", String(format: "%.0f%%", rate))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .appCard()
    }

    private func analyticsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).appFont(.callout).foregroundStyle(AppColor.baseContent.opacity(0.6))
            Spacer()
            Text(value).font(AppFont.money())
        }
    }
}

private struct CountTile: View {
    let value: Int
    let label: String
    let system: String
    var tint: Color = AppColor.primary

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: system).font(.title3).foregroundStyle(tint)
            Text("\(value)").font(AppFont.money(20, weight: .semibold))
            Text(label).appFont(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .appCard()
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
                .font(.body).foregroundStyle(AppColor.baseContent.opacity(0.5))
        }
    }
}
