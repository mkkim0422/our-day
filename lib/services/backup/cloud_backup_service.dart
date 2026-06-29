import 'dart:async';

/// 클라우드 백업 계층의 공통 추상화.
///
/// 1차 구현은 [GoogleDriveBackupService](구글 드라이브). 애플 iCloud 등은 같은
/// 인터페이스로 추가해 화면/로직 변경 없이 갈아끼운다(의존성 역전, 1장).
///
/// 백업 본체는 로컬과 동일한 단일 .zip(manifest+사진)을 재사용한다 —
/// 클라우드 계층은 그 zip의 **업로드/목록/다운로드/용량 확인**만 담당한다.

/// 로그인된 클라우드 계정.
class CloudAccount {
  const CloudAccount({required this.email, this.displayName, this.photoUrl});

  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// 클라우드 저장 용량 현황.
class CloudQuota {
  const CloudQuota({required this.usedBytes, this.limitBytes});

  /// 전체 용량(byte). null이면 무제한이거나 측정 불가.
  final int? limitBytes;
  final int usedBytes;

  /// 남은 용량(byte). 무제한이면 null.
  int? get freeBytes {
    final lim = limitBytes;
    if (lim == null) return null;
    final free = lim - usedBytes;
    return free < 0 ? 0 : free;
  }

  /// 사용률 0.0~1.0. 무제한이면 null.
  double? get usedRatio {
    final lim = limitBytes;
    if (lim == null || lim == 0) return null;
    final r = usedBytes / lim;
    return r > 1 ? 1 : r;
  }

  /// [addBytes]만큼 더 올리면 용량을 넘기는가(여유 [_safetyBuffer] 버퍼 포함).
  bool wouldOverflow(int addBytes) {
    final free = freeBytes;
    if (free == null) return false; // 무제한
    return addBytes + _safetyBuffer > free;
  }

  /// 업로드 중 다른 변동을 감안한 안전 여유분.
  static const _safetyBuffer = 10 * 1024 * 1024; // 10MB
}

/// 클라우드에 올라간 백업 1건.
class RemoteBackup {
  const RemoteBackup({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;
}

/// 클라우드 백업 오류 분류 — UI가 상황별로 다르게 안내(특히 용량 초과).
enum CloudErrorKind { notSignedIn, quotaExceeded, network, canceled, unknown }

class CloudBackupException implements Exception {
  const CloudBackupException(this.kind, this.message);

  final CloudErrorKind kind;
  final String message;

  @override
  String toString() => 'CloudBackupException($kind): $message';
}

/// 클라우드 백업 서비스 공통 인터페이스.
abstract class CloudBackupService {
  /// 사람이 읽는 서비스 이름(예: '구글 드라이브').
  String get providerName;

  /// 현재 로그인 계정(없으면 null).
  CloudAccount? get account;

  /// 로그인 상태 변화 스트림(UI 갱신용).
  Stream<CloudAccount?> get accountChanges;

  /// 앱/화면 진입 시 조용히 로그인 복원(이전에 로그인했으면). 실패해도 throw 안 함.
  Future<CloudAccount?> signInSilently();

  /// 사용자 동작으로 로그인(계정 선택 + 권한 동의). 사용자가 취소하면 null.
  Future<CloudAccount?> signIn();

  Future<void> signOut();

  /// 저장 용량 현황.
  Future<CloudQuota> quota();

  /// 로컬 zip 파일을 클라우드에 업로드.
  Future<RemoteBackup> upload(String zipPath,
      {void Function(double progress)? onProgress});

  /// 클라우드의 백업 목록(최신순).
  Future<List<RemoteBackup>> list();

  /// 원격 백업을 로컬 임시 파일로 내려받아 경로 반환.
  Future<String> download(RemoteBackup backup,
      {void Function(double progress)? onProgress});

  Future<void> delete(RemoteBackup backup);
}
