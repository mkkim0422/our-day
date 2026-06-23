/// 백업·복원 서비스 추상화 (8장 원칙).
///
/// 안드로이드=구글 드라이브, iOS=iCloud로 구현이 갈리므로 **인터페이스로 두고
/// 플랫폼별 구현을 주입**한다. 자체 서버에 사진을 보관하지 않으며(9장),
/// 사용자 본인 클라우드로만 백업한다. 전송·저장 구간은 암호화한다.
library;

export '../../core/constants/enums.dart' show BackupTarget, BackupState;

/// 백업 진행 상황 보고용.
class BackupProgress {
  const BackupProgress({
    required this.uploaded,
    required this.total,
    this.message,
  });

  final int uploaded;
  final int total;
  final String? message;

  double get fraction => total == 0 ? 0 : uploaded / total;
}

/// 플랫폼 무관 백업 인터페이스.
///
/// 구현체: `GoogleDriveBackupService`(Android), `ICloudBackupService`(iOS).
/// 작업 #7에서 구현. 여기서는 계약(인터페이스)만 확정한다.
abstract interface class BackupService {
  /// 사용자 클라우드 연결(소셜 로그인 스코프 포함). 성공 시 true.
  Future<bool> connect();

  /// 연결 해제.
  Future<void> disconnect();

  /// 현재 연결 여부.
  Future<bool> isConnected();

  /// 마지막 백업 시각(없으면 null).
  Future<DateTime?> lastBackupAt();

  /// 로컬 사진+DB 스냅샷을 사용자 클라우드로 업로드.
  Stream<BackupProgress> backup();

  /// 사용자 클라우드에서 사진+DB를 복원(기기 변경/재설치 대비).
  Stream<BackupProgress> restore();
}
