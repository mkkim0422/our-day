import 'dart:convert';

import 'package:drift/drift.dart';

/// json 객체(Map)를 DB의 text 컬럼에 저장하기 위한 컨버터.
///
/// 용도: `Project.schedule_config`, `Capture.alignment_meta` 등(2장).
class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    if (fromDb.isEmpty) return <String, dynamic>{};
    return jsonDecode(fromDb) as Map<String, dynamic>;
  }

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}
