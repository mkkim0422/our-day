import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/services/gallery/similar_photo_finder.dart';

/// 검색 전 "예상 시간" 계산(GallerySurvey) — 기기와 무관한 순수 로직 검증.
void main() {
  group('GallerySurvey 예측', () {
    test('estimate = 고정오버헤드 + 장당시간 × 장수', () {
      const s = GallerySurvey(total: 1000, msPerPhoto: 20, quickCount: 1000);
      // 3초(고정) + 20ms × 1000장 = 3 + 20 = 23초
      expect(s.estimate(1000).inSeconds, 23);
    });

    test('장당 시간이 빠르면 예상 시간도 짧다', () {
      const fast = GallerySurvey(total: 500, msPerPhoto: 5, quickCount: 500);
      const slow = GallerySurvey(total: 500, msPerPhoto: 40, quickCount: 500);
      expect(fast.quickEstimate < slow.quickEstimate, isTrue);
    });

    test('전체 검색은 빠른 검색보다 오래 걸린다(더 많은 장수)', () {
      const s = GallerySurvey(total: 6000, msPerPhoto: 15, quickCount: 500);
      expect(s.fullCount, greaterThan(s.quickCount));
      expect(s.fullEstimate > s.quickEstimate, isTrue);
    });

    test('fullCount는 1500장으로 상한(포즈검출 비용 때문에 무한정 못 봄)', () {
      const s = GallerySurvey(total: 33204, msPerPhoto: 90, quickCount: 500);
      expect(s.fullCount, 1500);
    });

    test('quickCount는 호출부가 정한 값을 그대로 반영', () {
      const s = GallerySurvey(total: 33204, msPerPhoto: 90, quickCount: 500);
      expect(s.quickCount, 500);
    });

    test('hasPhotos: 0장이면 false', () {
      expect(const GallerySurvey(total: 0, msPerPhoto: 30, quickCount: 0)
          .hasPhotos, isFalse);
      expect(const GallerySurvey(total: 1, msPerPhoto: 30, quickCount: 1)
          .hasPhotos, isTrue);
    });

    test('총 장수가 quickCount보다 적으면 fullCount=총 장수', () {
      const s = GallerySurvey(total: 30, msPerPhoto: 30, quickCount: 30);
      expect(s.fullCount, 30);
    });
  });
}
