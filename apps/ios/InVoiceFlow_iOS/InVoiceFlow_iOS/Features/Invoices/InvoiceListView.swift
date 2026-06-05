import SwiftUI

/// AMI-44 (iOS): invoice list with status filter, pull-to-refresh, and a
/// toolbar entry to create a new invoice. Tapping a row pushes the detail
/// view. Also the navigation target for QR deep-links (AMI-42) via
/// `selectedInvoiceId`.
struct InvoiceListView: View {
    @State private var vm = InvoiceListViewModel()
    @State private var showCreate = false
    @State private var path: [String] = []

    /// Set by the QR scanner deep-link to push straight to a detail screen.
    /// Consumed (reset to nil) once pushed onto the navigation path.
    @Binding var deepLinkInvoiceId: String?

    init(deepLinkInvoiceId: Binding<String?> = .constant(nil)) {
        self._deepLinkInvoiceId = deepLinkInvoiceId
    }

    private let filters: [(label: String, value: String?)] = [
        ("전체", nil),
        ("발송됨", "sent"),
        ("연체", "overdue"),
        ("결제완료", "paid"),
        ("초안", "draft"),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if vm.invoices.isEmpty && !vm.isLoading {
                    EmptyInvoices()
                } else {
                    List {
                        ForEach(vm.invoices) { invoice in
                            NavigationLink(value: invoice.id) {
                                InvoiceRow(invoice: invoice)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .safeAreaInset(edge: .top) { filterBar }
            .overlay { if let error = vm.error { ErrorBanner(message: error) } }
            .refreshable { await vm.refresh() }
            .task { await vm.refresh() }
            .navigationTitle("송장")
            .navigationDestination(for: String.self) { id in
                InvoiceDetailView(invoiceId: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("새 송장")
                }
            }
            .sheet(isPresented: $showCreate, onDismiss: { Task { await vm.refresh() } }) {
                InvoiceCreateView()
            }
        }
        // QR deep-link (AMI-42): push detail when a scanned id arrives, then
        // clear the binding so re-scanning the same code pushes again.
        .onChange(of: deepLinkInvoiceId) { _, newValue in
            guard let id = newValue else { return }
            path.append(id)
            deepLinkInvoiceId = nil
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.label) { filter in
                    let isOn = vm.statusFilter == filter.value
                    Button {
                        Task { await vm.setFilter(filter.value) }
                    } label: {
                        Text(filter.label)
                            .appFont(.callout)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isOn ? AppColor.primary : AppColor.base300,
                                in: .capsule
                            )
                            .foregroundStyle(isOn ? AppColor.primaryContent : AppColor.baseContent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }
}

private struct InvoiceRow: View {
    let invoice: InvoiceDTO
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(invoice.invoiceNumber)").font(.body.weight(.semibold))
                StatusBadge(status: invoice.status)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(MoneyFormatter.format(invoice.amount, currency: invoice.currency))
                    .font(.body)
                if let due = invoice.dueDate {
                    Text("기한 \(due)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: String
    var body: some View {
        // 웹 status_class / Android StatusColors 와 동일한 색 매핑.
        let (fg, bg) = AppColor.statusColor(for: status)
        Text(InvoiceStatus.label(status))
            .font(AppFont.caption.weight(.medium))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 2)
            .background(bg, in: .capsule)
            .foregroundStyle(fg)
    }
}

private struct EmptyInvoices: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "doc.text").font(.largeTitle)
                .foregroundStyle(AppColor.baseContent.opacity(0.2))
            Text("아직 송장이 없습니다").appFont(.bodyText)
                .foregroundStyle(AppColor.baseContent.opacity(0.7))
            Text("+ 버튼으로 첫 송장을 만들어 보세요.")
                .appFont(.caption).foregroundStyle(AppColor.baseContent.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .appFont(.caption)
                .foregroundStyle(AppColor.errorContent)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(AppColor.error.opacity(0.9), in: .rect(cornerRadius: AppRadius.button))
                .padding(AppSpacing.md)
        }
    }
}
