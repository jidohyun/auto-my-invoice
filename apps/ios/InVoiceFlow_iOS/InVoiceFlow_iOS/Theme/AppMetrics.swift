import SwiftUI

// ── AppMetrics ──────────────────────────────────────────────────
// 디자인 시스템 치수(radius / border / spacing) 단일 출처.
// 웹(app.css DaisyUI) + Android(Tokens.kt / Shape.kt) 와 동일한 값을 미러링.
// 외부 의존성 없음 — 이 파일만으로 컴파일된다.

// MARK: - Radius (모서리 반경)

/// 코너 반경 토큰. 웹 --radius-* / Android Shape.kt 매핑과 일치.
/// badge(=full/9999)는 SwiftUI에서 `Capsule()` 로 표현하므로 상수 대신 도형을 사용한다.
enum AppRadius {
    /// field: 8pt — 입력 필드 등 (Apple field 반경)
    static let field: CGFloat = 8
    /// button / selector: 8pt — 버튼, 셀렉터
    static let button: CGFloat = 8
    /// box / card: 18pt — 카드, 박스 (Apple store-utility-card 반경)
    static let card: CGFloat = 18
}

// MARK: - Border (테두리 두께)

/// 테두리 두께 토큰. 웹 --border: 1.5px / Android BorderWidth 1.5dp.
enum AppBorder {
    static let width: CGFloat = 1.5
}

// MARK: - Spacing (간격 스케일, 8pt 기준)

/// 간격 스케일. 웹 8px 기준 스페이싱 / Android SpaceXs…Space2xl 와 동일.
enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}

// MARK: - Card ViewModifier

/// 표준 카드 스타일. Apple 카드는 무그림자 + hairline 보더 룩을 따른다.
/// (base-200 표면, 18 코너, base-300 hairline 보더, 그림자 없음)
/// 색은 `AppColor` 의 base-200/base-300 적응형 토큰을 사용하므로 다크모드도 대응한다.
///
/// 사용: `someView.appCard()`  (패딩은 호출부 책임 — 콘텐츠 패딩과 분리)
struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColor.base200)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppColor.base300, lineWidth: AppBorder.width)
            )
            // Apple 카드는 그림자 없음 — 깊이는 hairline 보더로만 표현
    }
}

extension View {
    /// 표준 카드 스타일을 적용한다. (base-200 배경, 18 코너, 1.5 base-300 hairline 테두리, 무그림자)
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}
