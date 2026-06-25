import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/enums.dart';
import '../../data/repositories/providers.dart';
import '../providers.dart';

/// 첫 실행 온보딩용 샘플 데이터 시더.
///
/// 번들된 일러스트 5장(assets/sample)을 실제 저장소로 복사해 "우리 가족" 기록과
/// 5개의 촬영(아이가 점점 크는 성장)을 만든다. 사용자가 빈 화면 대신 타임랩스가
/// 도는 모습을 바로 보고 사용법을 직관적으로 익히게 하기 위함(리텐션).
class SampleSeeder {
  SampleSeeder(this._ref);

  final Ref _ref;

  static const _frameCount = 5;

  /// 프레임 i(1-base)의 에셋 바이트를 로드. png·jpg·jpeg·webp 순으로 시도해
  /// 사용자가 어떤 포맷으로 넣어도(예: AI가 만든 jpg) 인식되게 한다.
  Future<ByteData?> _loadFrame(int oneBasedIndex) async {
    for (final ext in const ['png', 'jpg', 'jpeg', 'webp']) {
      try {
        return await rootBundle.load('assets/sample/sample_$oneBasedIndex.$ext');
      } catch (_) {
        // 다음 확장자 시도.
      }
    }
    return null;
  }

  /// 촬영 시점(오래된→최근). 해는 매년 +1(2022→2026), 월은 **배경 계절**에 맞춤.
  /// 폴라로이드 날짜("YYYY년 M월")의 원천. 나이(생일 2020-01 기준)와 1:1로 증가.
  /// ① 바닷가=여름 ② 단풍=가을 ③ 눈=겨울 ④ 여행지=봄 ⑤ 겨울 숲=겨울.
  List<DateTime> _dates() => [
        DateTime(2022, 8),
        DateTime(2023, 10),
        DateTime(2024, 12),
        DateTime(2025, 5),
        DateTime(2026, 1),
      ];

  // 프레임별 키(cm) — 약 2→6세 성장 곡선.
  static const _heights = [88.0, 96.0, 104.0, 110.0, 116.0];
  // 폴라로이드 하단 손글씨 캡션(나이 + 장소 + 상황 이모지). 사진 배경에 맞춤.
  // 나이는 연도(매년 +1)와 1:1로 증가하도록 두·세·네·다섯·여섯 살.
  static const _notes = [
    '우리천사 두 살, 바닷가에서 🌊',
    '우리천사 세 살, 단풍 들 무렵 🍁',
    '우리천사 네 살, 눈 오던 날 ☃️',
    '우리천사 다섯 살, 여행지에서 ✈️',
    '우리천사 여섯 살, 겨울 숲에서 ❄️',
  ];

  /// 샘플 기록을 생성한다. (호출 전 중복 방지 플래그를 확인할 것.)
  Future<void> seed() async {
    final projectRepo = _ref.read(projectRepositoryProvider);
    final captureRepo = _ref.read(captureRepositoryProvider);
    final memberRepo = _ref.read(memberRepositoryProvider);
    final settings = _ref.read(appSettingsProvider.notifier);

    final project = await projectRepo.create(
      title: '우리 가족',
      scheduleType: ScheduleType.monthly,
      scheduleConfig: const {'day': 15},
      eventPegs: const {EventPeg.birthday, EventPeg.season},
    );

    // 구성원(전체 컷에 함께 태깅).
    final dad = await memberRepo.create(
        projectId: project.id, name: '아빠', role: '아빠');
    final mom = await memberRepo.create(
        projectId: project.id, name: '엄마', role: '엄마');
    final kid = await memberRepo.create(
        projectId: project.id, name: '아이', role: '첫째');
    final memberIds = [dad.id, mom.id, kid.id];

    // 아이 생일(나이 라벨용) — 각 컷에서 정확히 2·3·4·5·6세가 되도록 2020-01.
    final dates = _dates();
    await settings.setProjectBirthday(project.id, DateTime(2020, 1));

    // 샘플은 이미 경량(1280px)이라 썸네일 디코딩 없이 **파일만 직접 복사**한다
    // (첫 실행 로딩 단축 — 무거운 isolate 디코딩 5회 제거). file==thumb.
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'captures'));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    String? lastCaptureId;
    for (var i = 0; i < _frameCount; i++) {
      final bytes = await _loadFrame(i + 1);
      if (bytes == null) continue; // 해당 프레임 파일이 없으면 건너뜀.
      final path = p.join(dir.path, 'sample_${i + 1}.jpg');
      await File(path).writeAsBytes(bytes.buffer.asUint8List());

      final capture = await captureRepo.create(
        project: project,
        filePath: path,
        thumbPath: path, // 경량 원본을 썸네일로 겸용.
        capturedAt: dates[i],
        note: _notes[i],
      );
      await settings.setCaptureHeight(capture.id, _heights[i]);
      await memberRepo.setMembersForCapture(capture.id, memberIds);
      lastCaptureId = capture.id;
    }

    if (lastCaptureId != null) {
      await projectRepo.setCoverPhoto(project.id, lastCaptureId);
    }
  }

  /// 샘플 기록과 그 사진 파일·설정을 완전히 제거한다.
  /// (쇼케이스를 본 뒤 "내 기록 시작하기"에서 호출 → 내 사진 아닌 데이터가 안 남게.)
  Future<void> removeSample(String projectId) async {
    final projectRepo = _ref.read(projectRepositoryProvider);
    final captureRepo = _ref.read(captureRepositoryProvider);
    final storage = _ref.read(photoStorageProvider);
    final settings = _ref.read(appSettingsProvider.notifier);

    final caps = await captureRepo.listByProject(projectId);
    for (final c in caps) {
      await storage.deleteFiles(c.filePath, c.thumbPath);
      await settings.setCaptureHeight(c.id, null); // 키 기록 정리.
    }
    await settings.setProjectBirthday(projectId, null);
    // 프로젝트 삭제 → FK cascade로 captures/members/places DB 행도 함께 제거.
    await projectRepo.delete(projectId);
  }
}

final sampleSeederProvider =
    Provider<SampleSeeder>((ref) => SampleSeeder(ref));
