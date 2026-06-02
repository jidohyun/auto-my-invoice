import SwiftUI

// MARK: - AppFont
//
// AutoMyInvoice 디자인 시스템의 타이포그래피 헬퍼.
//
// 웹(Tailwind/DaisyUI)·Android(Typography.kt)와 동일한 폰트 패밀리를 사용한다:
//   - display(헤딩/KPI 숫자): "Space Grotesk"
//   - body(본문 전반):        "Inter"
//
// 아직 .ttf 폰트 파일이 번들에 포함돼 있지 않다. `Font.custom(_:size:)` 는
// 해당 패밀리를 찾지 못하면 같은 size 의 시스템 폰트로 **자동 폴백**하므로,
// 폰트 파일 없이도 코드는 깨지지 않고 동작한다(시스템 SF Pro 로 렌더링됨).
// 폰트 파일을 추가하면 별도 코드 변경 없이 즉시 적용된다.
//
// 폰트 파일 등록 방법은 파일 하단 "폰트 파일 등록(나중에)" 주석 참고.

enum AppFont {

    // MARK: 패밀리 이름 (PostScript / 패밀리 이름 기준)

    /// 디스플레이용 패밀리 — 헤딩, KPI 숫자 등.
    private static let displayFamily = "Space Grotesk"

    /// 본문용 패밀리 — 라벨, 캡션, 일반 텍스트.
    private static let bodyFamily = "Inter"

    // MARK: 폰트 빌더
    //
    // Font.custom(_:size:) 은 패밀리를 못 찾으면 시스템 폰트로 폴백한다.
    // weight 는 SwiftUI 의 .weight(_:) 모디파이어로 별도 지정한다(번들된
    // 폰트의 개별 weight 파일이 없어도 합성 weight 로 동작하도록).

    /// 디스플레이 폰트(Space Grotesk) — 지정 size/weight.
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(displayFamily, size: size).weight(weight)
    }

    /// 본문 폰트(Inter) — 지정 size/weight.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(bodyFamily, size: size).weight(weight)
    }

    // MARK: - 시맨틱 스타일 (웹 스케일 매핑)
    //
    // 웹 타입 스케일 기준:
    //   h1       = text-2xl(24px) / font-bold        → displayLarge
    //   섹션 헤딩 = ~20px / semibold(Space Grotesk)   → displayTitle
    //   카드 헤딩 = ~17px / semibold(Inter)            → headline
    //   본문      = 15~16px / regular(Inter)           → bodyText
    //   subtitle = text-sm(14px) base-content/60      → callout
    //   캡션      = 12px(Inter)                        → caption
    //   money    = font-mono(숫자/금액)                → money

    /// h1 — 화면 최상단 큰 제목. 웹 text-2xl(24px) font-bold, Space Grotesk.
    static var displayLarge: Font { display(24, weight: .bold) }

    /// 섹션 제목 — 20px semibold, Space Grotesk.
    static var displayTitle: Font { display(20, weight: .semibold) }

    /// 카드/그룹 헤딩 — 17px semibold, Inter.
    static var headline: Font { body(17, weight: .semibold) }

    /// 본문 — 15px regular, Inter.
    static var bodyText: Font { body(15, weight: .regular) }

    /// 서브타이틀/보조 텍스트 — 웹 subtitle text-sm(14px), Inter.
    /// (색상은 호출부에서 base-content/60 으로 지정)
    static var callout: Font { body(14, weight: .regular) }

    /// 캡션/메타 — 12px, Inter. 라벨·날짜·상태 보조 텍스트.
    static var caption: Font { body(12, weight: .regular) }

    /// 금액/숫자 — 웹 money(font-mono). 모노스페이스 + medium weight.
    /// KPI 숫자나 송장 금액처럼 자릿수 정렬이 필요한 곳에 사용.
    static func money(_ size: CGFloat = 17, weight: Font.Weight = .medium) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    /// 기본 money 스타일(17px medium 모노스페이스).
    static var moneyDefault: Font { money() }
}

// MARK: - 시맨틱 스타일 토큰 (점-단축 표기용)
//
// `.appFont(.displayLarge)` 처럼 점-단축으로 쓸 수 있도록 시맨틱 스타일을
// AppStyle 케이스로 노출한다. 시스템 Font 의 .headline/.callout/.caption 과
// 이름이 겹쳐도 AppStyle 네임스페이스 안이라 충돌하지 않는다.

enum AppFontStyle {
    case displayLarge
    case displayTitle
    case headline
    case bodyText
    case callout
    case caption

    var font: Font {
        switch self {
        case .displayLarge: return AppFont.displayLarge
        case .displayTitle: return AppFont.displayTitle
        case .headline:     return AppFont.headline
        case .bodyText:     return AppFont.bodyText
        case .callout:      return AppFont.callout
        case .caption:      return AppFont.caption
        }
    }
}

// MARK: - View 편의 모디파이어
//
// `.appFont(.displayLarge)` 형태로 호출부 가독성을 높인다.

extension View {
    /// AppFont 시맨틱 스타일을 적용한다.
    /// 예: `Text("한눈에 보기").appFont(.displayLarge)`
    func appFont(_ style: AppFontStyle) -> some View {
        self.font(style.font)
    }
}

// MARK: - 폰트 파일 등록(나중에)
//
// Space Grotesk / Inter 를 실제로 렌더링하려면 .ttf 파일을 번들에 추가하고
// Info.plist 의 UIAppFonts 에 등록해야 한다. 등록 전에는 시스템 폰트로 폴백된다.
//
// 1) 폰트 파일 추가
//    Theme/Fonts/ 디렉터리(또는 임의 경로)에 아래 파일을 넣고
//    Xcode 타깃의 "Copy Bundle Resources" 에 포함시킨다:
//      - SpaceGrotesk-Regular.ttf
//      - SpaceGrotesk-Medium.ttf
//      - SpaceGrotesk-SemiBold.ttf
//      - SpaceGrotesk-Bold.ttf
//      - Inter-Regular.ttf
//      - Inter-Medium.ttf
//      - Inter-SemiBold.ttf
//      - Inter-Bold.ttf
//
// 2) Info.plist 에 UIAppFonts 등록
//    <key>UIAppFonts</key>
//    <array>
//      <string>SpaceGrotesk-Regular.ttf</string>
//      <string>SpaceGrotesk-Medium.ttf</string>
//      <string>SpaceGrotesk-SemiBold.ttf</string>
//      <string>SpaceGrotesk-Bold.ttf</string>
//      <string>Inter-Regular.ttf</string>
//      <string>Inter-Medium.ttf</string>
//      <string>Inter-SemiBold.ttf</string>
//      <string>Inter-Bold.ttf</string>
//    </array>
//
// 3) 패밀리 이름 확인
//    Font.custom(_:size:) 에 넘기는 이름은 위 displayFamily/bodyFamily 상수
//    ("Space Grotesk", "Inter") — 폰트의 PostScript 패밀리 이름과 일치해야 한다.
//    번들 후 콘솔에서 아래로 실제 등록 이름을 확인할 수 있다:
//      for family in UIFont.familyNames.sorted() {
//          print(family, UIFont.fontNames(forFamilyName: family))
//      }
//    이름이 다르면 displayFamily/bodyFamily 상수 값만 맞춰주면 된다.
