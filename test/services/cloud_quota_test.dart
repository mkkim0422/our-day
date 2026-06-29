import 'package:flutter_test/flutter_test.dart';
import 'package:our_day/services/backup/cloud_backup_service.dart';

void main() {
  const mb = 1024 * 1024;
  const gb = 1024 * mb;

  test('freeBytes/usedRatio: 한도가 있으면 계산한다', () {
    const q = CloudQuota(usedBytes: 3 * gb, limitBytes: 15 * gb);
    expect(q.freeBytes, 12 * gb);
    expect(q.usedRatio, closeTo(0.2, 1e-9));
  });

  test('무제한(limit=null)이면 free/ratio는 null, 넘침도 없음', () {
    const q = CloudQuota(usedBytes: 100 * gb, limitBytes: null);
    expect(q.freeBytes, isNull);
    expect(q.usedRatio, isNull);
    expect(q.wouldOverflow(50 * gb), isFalse);
  });

  test('사용량이 한도를 넘어도 free는 음수가 아니라 0', () {
    const q = CloudQuota(usedBytes: 16 * gb, limitBytes: 15 * gb);
    expect(q.freeBytes, 0);
    expect(q.usedRatio, 1.0); // 1.0으로 클램프
  });

  test('wouldOverflow: 여유 10MB 버퍼를 포함해 판정', () {
    // 남은 용량 정확히 100MB.
    const q = CloudQuota(usedBytes: 15 * gb - 100 * mb, limitBytes: 15 * gb);
    expect(q.freeBytes, 100 * mb);
    // 80MB + 10MB 버퍼 = 90MB ≤ 100MB → 안 넘침.
    expect(q.wouldOverflow(80 * mb), isFalse);
    // 95MB + 10MB 버퍼 = 105MB > 100MB → 넘침.
    expect(q.wouldOverflow(95 * mb), isTrue);
  });

  test('limit=0이면 usedRatio는 null(0 나눗셈 회피)', () {
    const q = CloudQuota(usedBytes: 0, limitBytes: 0);
    expect(q.usedRatio, isNull);
  });
}
