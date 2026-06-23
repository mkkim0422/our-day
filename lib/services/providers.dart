import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera/photo_storage.dart';

/// 서비스 계층 의존성 주입(riverpod).
///
/// 카메라(`CameraService`)는 화면 수명주기에 묶이므로 화면 내부에서 생성하고,
/// 무상태 서비스만 여기서 provider로 제공한다.

final photoStorageProvider = Provider<PhotoStorage>((ref) => PhotoStorage());
