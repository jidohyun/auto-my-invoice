import SwiftUI

struct RegisterView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("회원가입")
                    .appFont(.displayLarge)
                Text("이메일과 비밀번호로 새 계정을 만듭니다")
                    .appFont(.callout)
                    .foregroundStyle(AppColor.baseContent.opacity(0.6))

                LabeledField(label: "이메일 주소") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                LabeledField(label: "비밀번호") {
                    SecureField("8자 이상", text: $password)
                        .textContentType(.newPassword)
                }

                if let error = auth.error {
                    Text(error).foregroundStyle(AppColor.error).appFont(.caption)
                }

                Button {
                    Task { await auth.register(email: email, password: password) }
                } label: {
                    if auth.isSubmitting {
                        ProgressView().tint(AppColor.primaryContent).frame(maxWidth: .infinity)
                    } else {
                        Text("계정 만들기").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.primary)
                .disabled(auth.isSubmitting || email.isEmpty || password.count < 8)
            }
            .padding(24)
        }
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
    }
}
