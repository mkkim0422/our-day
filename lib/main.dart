import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // riverpod 전역 스코프. 상태관리는 riverpod로 통일(1장).
  runApp(const ProviderScope(child: OurDayApp()));
}
