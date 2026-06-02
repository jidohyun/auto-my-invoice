import SwiftUI

struct RegisterView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var companyName = ""
    @State private var oauthNotice = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // 헤더
                VStack(spacing: AppSpacing.sm) {
                    Text("AutoMyInvoice 시작하기")
                        .appFont(.displayLarge)
                        .multilineTextAlignment(.center)
                    Text("송장 리마인더를 자동화하고 더 빠르게 수금하세요.")
                        .appFont(.callout)
                        .foregroundStyle(AppColor.baseContent.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                // 소셜 가입
                VStack(spacing: AppSpacing.sm) {
                    GoogleAuthButton(title: "Google로 가입") { oauthNotice = true }
                    GitHubAuthButton(title: "GitHub으로 가입") { oauthNotice = true }
                }

                OrDivider()

                // 가입 폼
                VStack(spacing: AppSpacing.md) {
                    LabeledField(label: "이메일 주소") {
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    LabeledField(label: "비밀번호") {
                        SecureField("최소 8자 이상", text: $password)
                            .textContentType(.newPassword)
                    }

                    LabeledField(label: "회사명 (선택)") {
                        TextField("회사명을 입력하세요", text: $companyName)
                            .textContentType(.organizationName)
                    }

                    if let error = auth.error {
                        Text(error)
                            .appFont(.caption)
                            .foregroundStyle(AppColor.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await auth.register(email: email, password: password, companyName: companyName) }
                    } label: {
                        if auth.isSubmitting {
                            ProgressView().tint(AppColor.primaryContent).frame(maxWidth: .infinity)
                        } else {
                            Text("계정 만들기").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.primary)
                    .controlSize(.large)
                    .disabled(auth.isSubmitting || email.isEmpty || password.count < 8)
                }

                // 로그인 안내
                HStack(spacing: AppSpacing.xs) {
                    Text("이미 계정이 있으신가요?")
                        .appFont(.callout)
                        .foregroundStyle(AppColor.baseContent.opacity(0.6))
                    Button("로그인") { dismiss() }
                        .appFont(.callout)
                        .foregroundStyle(AppColor.primary)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 460)
            .appCard()
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
        }
        .background(AppColor.base100)
        .navigationBarTitleDisplayMode(.inline)
        .alert("준비 중이에요", isPresented: $oauthNotice) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("소셜 가입은 곧 지원될 예정입니다. 지금은 이메일로 가입해 주세요.")
        }
    }
}
