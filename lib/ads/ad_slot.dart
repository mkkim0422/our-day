import 'package:flutter/material.dart';

/// 광고 슬롯 컴포넌트 (6-1장).
///
/// 광고 영역을 **별도 슬롯으로 분리**해, 프리미엄 사용자/광고 미노출 시
/// 자연스럽게 사라지고 레이아웃이 깨지지 않게 한다.
///
/// 배치 규칙(6-1장):
/// - 허용: 홈/타임라인 하단 배너 1개, 앨범 그리드 사이 네이티브, 타임랩스 생성완료 직후 전면.
/// - 금지: 촬영 화면, 회상 알림·비교 뷰, 아동 사진에 밀착, 앱 실행 직후/촬영 흐름 중간.
///
/// MVP에서는 실제 AdMob 연동 전까지 빈 슬롯(높이 0)으로 동작.
/// 실제 연동은 작업 #9에서 `google_mobile_ads`로 구현.
class AdSlot extends StatelessWidget {
  const AdSlot({
    super.key,
    required this.placement,
    this.adsRemoved = false,
  });

  final AdPlacement placement;

  /// 프리미엄(광고 제거) 사용자 여부. true면 슬롯이 완전히 사라진다.
  final bool adsRemoved;

  @override
  Widget build(BuildContext context) {
    if (adsRemoved) return const SizedBox.shrink();
    // TODO(#9): placement별 AdMob 광고 위젯 주입. 현재는 빈 슬롯.
    return const SizedBox.shrink();
  }
}

/// 광고가 허용된 배치 위치 (금지 위치는 enum에 존재하지 않음 → 구조적으로 차단).
enum AdPlacement {
  homeBanner,
  albumNative,
  timelapseDoneInterstitial,
}
