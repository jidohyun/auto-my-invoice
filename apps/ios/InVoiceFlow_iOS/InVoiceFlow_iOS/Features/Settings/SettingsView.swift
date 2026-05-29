import SwiftUI

/// AMI-44 (iOS): settings screen — profile, notification toggles, payment
/// terms, currency — plus a logout action. Notification toggles are local and
/// drive APNs registration (AMI-41).
struct SettingsView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                if let error = vm.error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
                }

                Section("프로필") {
                    if let settings = vm.settings {
                        LabeledContent("이메일", value: settings.email)
                        if let plan = settings.plan {
                            LabeledContent("플랜", value: plan.uppercased())
                        }
                    }
                    TextField("회사명", text: $vm.companyName)
                }

                Section("청구 기본값") {
                    Picker("기본 통화", selection: $vm.defaultCurrency) {
                        ForEach(vm.currencies, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("결제 기한", selection: $vm.paymentTerms) {
                        ForEach(vm.paymentTermsOptions, id: \.self) { Text("\($0)일").tag($0) }
                    }
                    TextField("송장 번호 접두사", text: $vm.invoicePrefix)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section {
                    Toggle("푸시 알림", isOn: $vm.pushEnabled)
                    Toggle("결제 기한 리마인더", isOn: $vm.reminderDueEnabled)
                        .disabled(!vm.pushEnabled)
                    Toggle("결제 수신 알림", isOn: $vm.paymentReceivedEnabled)
                        .disabled(!vm.pushEnabled)
                } header: {
                    Text("알림")
                } footer: {
                    Text("푸시를 켜면 송장 리마인더와 결제 알림을 받습니다.")
                }
                .onChange(of: vm.pushEnabled) { _, enabled in
                    if enabled { Task { await PushManager.shared.registerIfEnabled() } }
                }

                Section {
                    Button(role: .destructive) {
                        auth.logOut()
                    } label: {
                        Text("로그아웃").frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("설정")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { Task { await vm.save() } }
                        .disabled(vm.isSaving)
                }
            }
            .overlay {
                if vm.isLoading { ProgressView() }
            }
            .task { await vm.load() }
        }
    }
}
