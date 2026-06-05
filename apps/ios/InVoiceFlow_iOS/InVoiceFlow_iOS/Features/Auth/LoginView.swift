import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var oauthNotice = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // 헤더
                    VStack(spacing: AppSpacing.sm) {
                        Text("다시 오신 걸 환영합니다")
                            .appFont(.displayLarge)
                            .multilineTextAlignment(.center)
                        Text("로그인하여 송장을 관리하세요")
                            .appFont(.callout)
                            .foregroundStyle(AppColor.baseContent.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)

                    // 소셜 로그인
                    VStack(spacing: AppSpacing.sm) {
                        GoogleAuthButton(title: "Google로 로그인") { oauthNotice = true }
                        GitHubAuthButton(title: "GitHub으로 로그인") { oauthNotice = true }
                    }

                    OrDivider()

                    // 이메일/비밀번호 폼
                    VStack(spacing: AppSpacing.md) {
                        LabeledField(label: "이메일 주소") {
                            TextField("you@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            LabeledField(label: "비밀번호") {
                                SecureField("8자 이상", text: $password)
                                    .textContentType(.password)
                            }
                            // 비밀번호 찾기 (웹 링크와 동일 위치 — 실동작은 웹으로 안내)
                            Button("비밀번호를 잊으셨나요?") { oauthNotice = true }
                                .appFont(.caption)
                                .foregroundStyle(AppColor.primary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if let error = auth.error {
                            Text(error)
                                .appFont(.caption)
                                .foregroundStyle(AppColor.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await auth.login(email: email, password: password) }
                        } label: {
                            if auth.isSubmitting {
                                ProgressView().tint(AppColor.primaryContent).frame(maxWidth: .infinity)
                            } else {
                                Text("로그인").frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColor.primary)
                        .controlSize(.large)
                        .disabled(auth.isSubmitting || email.isEmpty || password.isEmpty)
                    }

                    // 회원가입 안내
                    HStack(spacing: AppSpacing.xs) {
                        Text("계정이 없으신가요?")
                            .appFont(.callout)
                            .foregroundStyle(AppColor.baseContent.opacity(0.6))
                        Button("회원가입") { showRegister = true }
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
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
            .alert("준비 중이에요", isPresented: $oauthNotice) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("소셜 로그인은 곧 지원될 예정입니다. 지금은 이메일로 로그인해 주세요.")
            }
        }
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label).appFont(.caption).foregroundStyle(AppColor.baseContent.opacity(0.6))
            content()
                .textFieldStyle(.roundedBorder)
        }
    }
}
