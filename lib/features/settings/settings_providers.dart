import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/providers.dart';
import '../../services/backup/local_backup_service.dart';
import '../../services/providers.dart';

/// 설정/백업(③ 화면) 상태 프로바이더.

/// 현재 로그인 계정(없으면 null).
final currentAccountProvider = StreamProvider<Account?>(
  (ref) => ref.watch(accountRepositoryProvider).watchCurrent(),
);

/// 로컬 백업 파일 목록(최신순). 백업 생성/복원 후 invalidate 해 갱신.
final backupsProvider = FutureProvider<List<BackupFileInfo>>(
  (ref) => ref.watch(localBackupServiceProvider).listBackups(),
);
