import 'dart:io';

import 'package:exif/exif.dart';

/// 갤러리에서 불러온 사진의 **실제 촬영일**(EXIF)을 읽는다.
///
/// 백필·단일 불러오기에서 "오늘/임의 날짜" 대신 사진 정보에 적힌 찍은 날을
/// 살리는 데 쓴다. EXIF가 없거나(스크린샷·일부 HEIC 등) 형식이 이상하면 null →
/// 호출 측에서 적절한 기본값으로 폴백한다.
Future<DateTime?> readPhotoTakenDate(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final tags = await readExifFromBytes(bytes);
    if (tags.isEmpty) return null;
    final raw = tags['EXIF DateTimeOriginal']?.printable ??
        tags['EXIF DateTimeDigitized']?.printable ??
        tags['Image DateTime']?.printable;
    return parseExifDateTime(raw);
  } catch (_) {
    // 디코딩 실패·권한·클라우드 전용 URI 등은 조용히 폴백.
    return null;
  }
}

/// EXIF 날짜 문자열("YYYY:MM:DD HH:MM:SS")을 [DateTime]으로 파싱.
///
/// EXIF는 보통 콜론 구분이지만 일부 기기는 하이픈/`T`를 쓰기도 해 함께 허용한다.
/// "0000:00:00 00:00:00"처럼 비어 있는 값은 null로 본다.
DateTime? parseExifDateTime(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'(\d{4})[:\-](\d{2})[:\-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
      .firstMatch(raw.trim());
  if (m == null) return null;
  final year = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  final day = int.parse(m[3]!);
  if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime(
    year,
    month,
    day,
    int.parse(m[4]!),
    int.parse(m[5]!),
    int.parse(m[6]!),
  );
}
