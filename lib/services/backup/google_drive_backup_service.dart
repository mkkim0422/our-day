import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cloud_backup_service.dart';

/// 구글 드라이브 백업 — 사용자 본인 드라이브의 **숨김 앱 폴더(appDataFolder)**에
/// .zip을 올린다. 우리 서버 비용 0, 사용자 눈에 안 보이는 전용 영역이라 깔끔하다.
///
/// 거대한 `googleapis` 대신 Drive REST(v3)를 `http`로 직접 호출한다:
///  · GET about?fields=storageQuota          → 용량
///  · POST upload(resumable) + PUT(청크)      → 업로드(대용량 대비 청크 전송)
///  · GET files?spaces=appDataFolder          → 목록
///  · GET files/{id}?alt=media                → 다운로드
///  · DELETE files/{id}                        → 삭제
///
/// 로그인/토큰은 `google_sign_in`이 담당(드라이브 appdata 스코프).
class GoogleDriveBackupService implements CloudBackupService {
  GoogleDriveBackupService();

  /// 앱 전용 숨김 폴더만 접근 — 사용자의 다른 드라이브 파일은 못 본다(최소 권한).
  static const _scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const _host = 'www.googleapis.com';
  static const _chunkSize = 8 * 1024 * 1024; // 8MB

  final GoogleSignIn _gsi = GoogleSignIn(scopes: const [_scope]);
  final http.Client _http = http.Client();

  @override
  String get providerName => '구글 드라이브';

  @override
  CloudAccount? get account => _toAccount(_gsi.currentUser);

  @override
  Stream<CloudAccount?> get accountChanges =>
      _gsi.onCurrentUserChanged.map(_toAccount);

  @override
  Future<CloudAccount?> signInSilently() async {
    try {
      return _toAccount(await _gsi.signInSilently());
    } catch (_) {
      return null; // 조용한 복원은 실패해도 무시.
    }
  }

  @override
  Future<CloudAccount?> signIn() async {
    final GoogleSignInAccount? acct;
    try {
      acct = await _gsi.signIn();
    } catch (e) {
      throw CloudBackupException(CloudErrorKind.unknown, '로그인 중 오류: $e');
    }
    if (acct == null) return null; // 사용자 취소
    final granted = await _gsi.requestScopes(const [_scope]);
    if (!granted) {
      throw const CloudBackupException(
          CloudErrorKind.notSignedIn, '드라이브 접근 권한이 필요해요.');
    }
    return _toAccount(acct);
  }

  @override
  Future<void> signOut() async {
    try {
      await _gsi.disconnect();
    } catch (_) {
      await _gsi.signOut();
    }
  }

  @override
  Future<CloudQuota> quota() async {
    final headers = await _authHeaders();
    final res = await _http.get(
      Uri.https(_host, '/drive/v3/about', {'fields': 'storageQuota'}),
      headers: headers,
    );
    if (res.statusCode != 200) _throwHttp(res.statusCode, res.body);
    final sq = (jsonDecode(res.body) as Map<String, dynamic>)['storageQuota']
            as Map<String, dynamic>? ??
        const {};
    return CloudQuota(
      usedBytes: _parseInt(sq['usage']) ?? 0,
      limitBytes: _parseInt(sq['limit']), // 키 없으면 무제한
    );
  }

  @override
  Future<RemoteBackup> upload(String zipPath,
      {void Function(double progress)? onProgress}) async {
    final file = File(zipPath);
    final total = await file.length();

    // 올리기 전에 용량을 확인해 미리 막는다(부분 업로드 후 실패 방지).
    if ((await quota()).wouldOverflow(total)) {
      throw const CloudBackupException(
          CloudErrorKind.quotaExceeded, '클라우드 용량이 부족해요.');
    }

    final headers = await _authHeaders();

    // 1) resumable 세션 시작 — 메타데이터(이름·부모 폴더)만 먼저 보낸다.
    final start = await _http.post(
      Uri.https(_host, '/upload/drive/v3/files',
          {'uploadType': 'resumable', 'fields': 'id,name,size,modifiedTime'}),
      headers: {
        ...headers,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'application/zip',
        'X-Upload-Content-Length': '$total',
      },
      body: jsonEncode({
        'name': p.basename(zipPath),
        'parents': ['appDataFolder'],
      }),
    );
    if (start.statusCode != 200) _throwHttp(start.statusCode, start.body);
    final sessionUri = start.headers['location'];
    if (sessionUri == null) {
      throw const CloudBackupException(
          CloudErrorKind.unknown, '업로드 세션을 열지 못했어요.');
    }

    // 2) 청크 PUT(진행률 보고 + 대용량 안전).
    final raf = await file.open();
    http.Response? done;
    try {
      var sent = 0;
      while (sent < total) {
        final end = math.min(sent + _chunkSize, total);
        await raf.setPosition(sent);
        final chunk = await raf.read(end - sent);
        final res = await _http.put(
          Uri.parse(sessionUri),
          headers: {
            ...headers,
            'Content-Length': '${chunk.length}',
            'Content-Range': 'bytes $sent-${end - 1}/$total',
          },
          body: chunk,
        );
        if (res.statusCode == 200 || res.statusCode == 201) {
          done = res; // 마지막 청크 → 파일 리소스 반환.
        } else if (res.statusCode == 308) {
          // 계속 업로드(미완).
        } else if (res.statusCode == 403 &&
            res.body.contains('storageQuotaExceeded')) {
          throw const CloudBackupException(
              CloudErrorKind.quotaExceeded, '클라우드 용량이 부족해요.');
        } else {
          _throwHttp(res.statusCode, res.body);
        }
        sent = end;
        onProgress?.call(sent / total);
      }
    } finally {
      await raf.close();
    }

    final body = done?.body;
    if (body == null || body.isEmpty) {
      throw const CloudBackupException(
          CloudErrorKind.unknown, '업로드 응답이 비어 있어요.');
    }
    return _toBackup(jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  Future<List<RemoteBackup>> list() async {
    final headers = await _authHeaders();
    final res = await _http.get(
      Uri.https(_host, '/drive/v3/files', {
        'spaces': 'appDataFolder',
        'orderBy': 'modifiedTime desc',
        'pageSize': '100',
        'fields': 'files(id,name,size,modifiedTime)',
      }),
      headers: headers,
    );
    if (res.statusCode != 200) _throwHttp(res.statusCode, res.body);
    final files = (jsonDecode(res.body) as Map<String, dynamic>)['files']
            as List<dynamic>? ??
        const [];
    return files
        .map((f) => _toBackup(f as Map<String, dynamic>))
        .where((b) => b.name.toLowerCase().endsWith('.zip'))
        .toList();
  }

  @override
  Future<String> download(RemoteBackup backup,
      {void Function(double progress)? onProgress}) async {
    final headers = await _authHeaders();
    final req = http.Request(
      'GET',
      Uri.https(_host, '/drive/v3/files/${backup.id}', {'alt': 'media'}),
    )..headers.addAll(headers);
    final res = await _http.send(req);
    if (res.statusCode != 200) {
      _throwHttp(res.statusCode, await res.stream.bytesToString());
    }
    final dir = await getTemporaryDirectory();
    final outPath = p.join(dir.path, backup.name);
    final sink = File(outPath).openWrite();
    final total = backup.sizeBytes;
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
    return outPath;
  }

  @override
  Future<void> delete(RemoteBackup backup) async {
    final headers = await _authHeaders();
    final res = await _http.delete(
      Uri.https(_host, '/drive/v3/files/${backup.id}'),
      headers: headers,
    );
    if (res.statusCode != 200 && res.statusCode != 204) {
      _throwHttp(res.statusCode, res.body);
    }
  }

  /// http.Client 정리(provider dispose에서 호출).
  void dispose() => _http.close();

  // ── 내부 ──

  Future<Map<String, String>> _authHeaders() async {
    var user = _gsi.currentUser;
    user ??= await _gsi.signInSilently();
    if (user == null) {
      throw const CloudBackupException(
          CloudErrorKind.notSignedIn, '로그인이 필요해요.');
    }
    final token = (await user.authentication).accessToken;
    if (token == null) {
      throw const CloudBackupException(
          CloudErrorKind.notSignedIn, '인증 토큰을 가져오지 못했어요.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  CloudAccount? _toAccount(GoogleSignInAccount? a) => a == null
      ? null
      : CloudAccount(
          email: a.email, displayName: a.displayName, photoUrl: a.photoUrl);

  RemoteBackup _toBackup(Map<String, dynamic> f) => RemoteBackup(
        id: f['id'] as String,
        name: (f['name'] as String?) ?? 'backup.zip',
        sizeBytes: _parseInt(f['size']) ?? 0,
        modifiedAt: DateTime.tryParse('${f['modifiedTime'] ?? ''}')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  int? _parseInt(Object? v) => v == null ? null : int.tryParse(v.toString());

  Never _throwHttp(int status, String body) {
    if (status == 401 || status == 403) {
      if (body.contains('storageQuotaExceeded')) {
        throw const CloudBackupException(
            CloudErrorKind.quotaExceeded, '클라우드 용량이 부족해요.');
      }
      throw CloudBackupException(
          CloudErrorKind.notSignedIn, '인증에 실패했어요($status).');
    }
    throw CloudBackupException(CloudErrorKind.network, '드라이브 오류($status)');
  }
}
