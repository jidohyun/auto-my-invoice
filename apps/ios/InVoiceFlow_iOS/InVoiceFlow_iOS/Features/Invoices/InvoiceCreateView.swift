import SwiftUI

/// AMI-44 (iOS): new-invoice form presented as a sheet from the invoice list.
/// Client picker + currency + line items + optional due date and notes.
struct InvoiceCreateView: View {
    @State private var vm: InvoiceCreateViewModel
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @Environment(\.dismiss) private var dismiss

    init() {
        _vm = State(initialValue: InvoiceCreateViewModel())
        _hasDueDate = State(initialValue: false)
        _dueDate = State(initialValue: Date())
    }

    /// OCR entry point (AMI-46): seed the form from an extraction result.
    init(prefill: ExtractedDataDTO) {
        let model = InvoiceCreateViewModel(prefill: prefill)
        _vm = State(initialValue: model)
        _hasDueDate = State(initialValue: model.dueDate != nil)
        _dueDate = State(initialValue: model.dueDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = vm.error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }

                if let notice = vm.prefillNotice {
                    Section {
                        Label(notice, systemImage: "sparkles")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section("고객") {
                    if vm.clients.isEmpty {
                        Text(vm.isLoadingClients ? "불러오는 중..." : "고객이 없습니다. 먼저 고객을 등록하세요.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Picker("고객 선택", selection: $vm.selectedClientId) {
                            ForEach(vm.clients) { client in
                                Text(client.name).tag(Optional(client.id))
                            }
                        }
                    }
                }

                Section("통화") {
                    Picker("통화", selection: $vm.currency) {
                        ForEach(vm.currencies, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("항목") {
                    ForEach($vm.items) { $item in
                        LineItemEditor(item: $item) {
                            vm.removeItem(item)
                        }
                    }
                    Button {
                        vm.addItem()
                    } label: {
                        Label("항목 추가", systemImage: "plus.circle")
                    }
                }

                Section("결제 기한") {
                    Toggle("기한 설정", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("기한", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("메모") {
                    TextField("선택 사항", text: $vm.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("새 송장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("생성") {
                        vm.dueDate = hasDueDate ? dueDate : nil
                        Task {
                            if await vm.submit() != nil { dismiss() }
                        }
                    }
                    .disabled(!vm.canSubmit)
                }
            }
            .overlay {
                if vm.isSubmitting {
                    ProgressView().controlSize(.large)
                }
            }
            .task { await vm.loadClients() }
        }
    }
}

private struct LineItemEditor: View {
    @Binding var item: InvoiceCreateViewModel.DraftItem
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("설명", text: $item.description)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            HStack {
                TextField("수량", text: $item.quantity)
                    .keyboardType(.decimalPad)
                Divider()
                TextField("단가", text: $item.unitPrice)
                    .keyboardType(.decimalPad)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}
