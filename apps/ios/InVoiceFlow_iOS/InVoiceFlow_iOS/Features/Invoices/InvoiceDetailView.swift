import SwiftUI

/// AMI-44 (iOS): invoice detail. Shows header (number/status/amount), client,
/// line items, and notes; offers Send and Mark-Paid actions gated on status.
/// Also the destination for QR pay deep-links (AMI-42).
struct InvoiceDetailView: View {
    @State private var vm: InvoiceDetailViewModel
    @State private var showDeleteConfirm = false
    @State private var showPaymentSheet = false
    @State private var paymentAmount = ""
    @Environment(\.dismiss) private var dismiss

    init(invoiceId: String) {
        self._vm = State(initialValue: InvoiceDetailViewModel(invoiceId: invoiceId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let invoice = vm.invoice {
                    // Inline error (e.g. a failed action) above the loaded content.
                    if let error = vm.error {
                        Text(error)
                            .font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 8))
                    }
                    header(invoice)
                    if let client = invoice.client { clientSection(client) }
                    itemsSection(invoice)
                    if let notes = invoice.notes, !notes.isEmpty { notesSection(notes) }
                    actions(invoice)
                } else if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if let error = vm.error {
                    // Load failed with nothing to show — recover with retry.
                    ErrorStateView(message: error) { Task { await vm.load() } }
                        .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .navigationTitle(vm.invoice.map { "#\($0.invoiceNumber)" } ?? "송장")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .confirmationDialog("이 송장을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                Task { if await vm.delete() { dismiss() } }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제한 송장은 복구할 수 없습니다.")
        }
        .alert("부분 결제 기록", isPresented: $showPaymentSheet) {
            TextField("금액", text: $paymentAmount)
                .keyboardType(.decimalPad)
            Button("기록") {
                Task { await vm.recordPayment(amount: paymentAmount) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("받은 금액을 입력하세요. 잔액을 초과할 수 없습니다.")
        }
        .sheet(isPresented: Binding(
            get: { vm.pdfShareURL != nil },
            set: { if !$0 { vm.pdfShareURL = nil } }
        )) {
            if let url = vm.pdfShareURL {
                ShareSheet(items: [url])
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = vm.toast {
                Text(toast)
                    .font(.subheadline)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: .capsule)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        vm.toast = nil
                    }
            }
        }
        .animation(.default, value: vm.toast)
    }

    private func header(_ invoice: InvoiceDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(invoice.invoiceNumber)").font(.title2.bold())
                Spacer()
                StatusBadge(status: invoice.status)
            }
            Text(MoneyFormatter.format(invoice.amount, currency: invoice.currency))
                .font(.largeTitle.weight(.semibold))
            if let due = invoice.dueDate {
                Label("결제 기한 \(due)", systemImage: "calendar")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private func clientSection(_ client: ClientDTO) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("고객").font(.headline)
                Text(client.name).font(.body.weight(.medium))
                if let email = client.email { Text(email).font(.caption).foregroundStyle(.secondary) }
                if let company = client.company { Text(company).font(.caption).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func itemsSection(_ invoice: InvoiceDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("항목").font(.headline)
            let items = invoice.items ?? []
            if items.isEmpty {
                Text("항목이 없습니다.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.description).font(.body)
                            Text("\(item.quantity) × \(MoneyFormatter.format(item.unitPrice, currency: invoice.currency))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("메모").font(.headline)
            Text(notes).font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actions(_ invoice: InvoiceDTO) -> some View {
        let status = invoice.status.lowercased()
        // Statuses where the invoice has been issued and still owes a balance.
        let unpaid = ["sent", "overdue", "partially_paid"].contains(status)

        return VStack(spacing: 12) {
            if status == "draft" {
                Button {
                    Task { await vm.send() }
                } label: {
                    actionLabel("송장 발송", system: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isActing)
            }

            if unpaid {
                Button {
                    Task { await vm.markPaid() }
                } label: {
                    actionLabel("결제 완료 처리", system: "checkmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(vm.isActing)

                Button {
                    paymentAmount = ""
                    showPaymentSheet = true
                } label: {
                    Label("부분 결제 기록", systemImage: "won.sign.circle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(vm.isActing)

                Button {
                    Task { await vm.sendReminder() }
                } label: {
                    actionLabel("리마인더 발송", system: "bell.badge")
                }
                .buttonStyle(.bordered)
                .disabled(vm.isActing)
            }

            // PDF is available for any non-draft invoice (it needs a rendered
            // document); the server still allows draft, but offering it after
            // issue matches the web flow.
            Button {
                Task { await vm.downloadPDF() }
            } label: {
                if vm.isDownloadingPDF {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Label("PDF 다운로드", systemImage: "arrow.down.doc").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(vm.isActing || vm.isDownloadingPDF)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("송장 삭제", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(vm.isActing)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionLabel(_ title: String, system: String) -> some View {
        Group {
            if vm.isActing {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Label(title, systemImage: system).frame(maxWidth: .infinity)
            }
        }
    }
}
