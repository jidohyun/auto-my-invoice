import SwiftUI

// MARK: - OAuth 버튼 (웹 로그인/회원가입 화면과 동일한 구성)
//
// 웹 user_login_live / user_registration_live 의 소셜 로그인 버튼을 그대로 옮김:
//   - Google: 아웃라인 버튼 + 멀티컬러 'G' 로고
//   - GitHub: 검정(#24292F) 버튼 + 흰색 마크
//
// 현재는 UI 만 동기화한 상태로, 탭 시 onTap 콜백을 호출한다(백엔드 OAuth
// 실동작은 추후 연결). 호출부에서 "준비 중" 안내 등을 띄운다.

/// Google 로그인/가입 버튼 — 아웃라인 + 컬러 'G'.
struct GoogleAuthButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GoogleGLogo().frame(width: 18, height: 18)
                Text(title).appFont(.headline)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(AppColor.base200, in: .rect(cornerRadius: AppRadius.button))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .strokeBorder(AppColor.base300, lineWidth: AppBorder.width)
            )
            .foregroundStyle(AppColor.baseContent)
        }
        .buttonStyle(.plain)
    }
}

/// GitHub 로그인/가입 버튼 — 검정 배경 + 흰 마크.
struct GitHubAuthButton: View {
    let title: String
    let action: () -> Void

    private let githubBg = Color(.sRGB, red: 0x24 / 255, green: 0x29 / 255, blue: 0x2F / 255)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 15, weight: .bold))
                Text(title).appFont(.headline)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(githubBg, in: .rect(cornerRadius: AppRadius.button))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// "또는 이메일로 계속" 구분선 — 웹의 좌우 라인 + 가운데 라벨.
struct OrDivider: View {
    var label: String = "또는 이메일로 계속"
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Rectangle().fill(AppColor.base300).frame(height: AppBorder.width)
            Text(label)
                .appFont(.callout)
                .foregroundStyle(AppColor.baseContent.opacity(0.4))
                .fixedSize()
            Rectangle().fill(AppColor.base300).frame(height: AppBorder.width)
        }
    }
}

// MARK: - Google 'G' 로고 (멀티컬러)
//
// 웹 SVG 의 4색 'G' 를 SwiftUI 로 근사한다. 정확한 벡터 대신 브랜드 4색
// (파랑/초록/노랑/빨강) 호(arc)와 가운데 가로 바로 인식 가능한 'G' 를 그린다.

private struct GoogleGLogo: View {
    private let blue = Color(.sRGB, red: 0x42 / 255, green: 0x85 / 255, blue: 0xF4 / 255)
    private let green = Color(.sRGB, red: 0x34 / 255, green: 0xA8 / 255, blue: 0x53 / 255)
    private let yellow = Color(.sRGB, red: 0xFB / 255, green: 0xBC / 255, blue: 0x05 / 255)
    private let red = Color(.sRGB, red: 0xEA / 255, green: 0x43 / 255, blue: 0x35 / 255)

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let lineWidth = s * 0.24
            ZStack {
                // 4색 호: 빨강(상) → 파랑(우) → 초록(하) → 노랑(좌)
                ringArc(from: 0.06, to: 0.27, color: blue, s: s, lineWidth: lineWidth)
                ringArc(from: 0.27, to: 0.52, color: green, s: s, lineWidth: lineWidth)
                ringArc(from: 0.52, to: 0.80, color: yellow, s: s, lineWidth: lineWidth)
                ringArc(from: 0.80, to: 1.06, color: red, s: s, lineWidth: lineWidth)
                // 'G' 의 가로 바 (파랑) — 오른쪽 가운데에서 중심으로
                Rectangle()
                    .fill(blue)
                    .frame(width: s * 0.30, height: lineWidth)
                    .position(x: s * 0.62, y: s * 0.5)
            }
            .frame(width: s, height: s)
        }
    }

    private func ringArc(from: CGFloat, to: CGFloat, color: Color, s: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .frame(width: s - lineWidth, height: s - lineWidth)
            .rotationEffect(.degrees(-90))
            .position(x: s * 0.5, y: s * 0.5)
    }
}
