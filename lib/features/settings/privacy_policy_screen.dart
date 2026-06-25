import 'package:flutter/material.dart';

/// 개인정보 처리방침 — 앱의 로컬 우선·자체서버 미보관 원칙(9장)을 평이하게 안내.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      '한눈에',
      '그날 우리는 가족 사진을 다루는 만큼 개인정보를 최소한으로, 안전하게 다룹니다. '
          '모든 사진과 기록은 기본적으로 사용자의 기기에만 저장되며, 우리 서버로 전송하거나 보관하지 않습니다.',
    ),
    (
      '사진·기록',
      '촬영하거나 불러온 사진, 메모, 키·나이 같은 기록은 기기 내부 저장소에만 보관됩니다. '
          '사용자가 직접 공유하거나 내보내기 전에는 어떤 사진도 외부로 나가지 않습니다.',
    ),
    (
      '위치',
      '위치 기반 회상 알림을 켠 경우에만 위치를 사용합니다. 좌표는 “이 장소의 추억”을 띄우는 '
          '용도로만 기기에 저장되며, 광고나 추적에 사용하거나 외부로 전송하지 않습니다. 설정에서 언제든 끌 수 있습니다.',
    ),
    (
      '카메라·사진 권한',
      '사진을 찍고 갤러리에서 불러오기 위해 카메라·사진 접근 권한을 사용합니다. '
          '권한은 해당 기능을 쓸 때만 요청합니다.',
    ),
    (
      '알림',
      '촬영 리마인더·회상 알림은 모두 기기에서 로컬로 예약됩니다. 알림을 위해 개인정보를 수집하지 않습니다.',
    ),
    (
      '폰트',
      '꾸미기의 일부 글꼴은 표시를 위해 Google Fonts에서 내려받아 기기에 캐시됩니다. '
          '이 과정에서 사진이나 개인정보는 전송되지 않습니다.',
    ),
    (
      '제3자 제공',
      '현재 사진·위치·기록을 제3자에게 제공하지 않습니다. 향후 인쇄·포토북 같은 기능을 추가할 경우, '
          '필요한 정보와 제공 대상을 명확히 고지하고 동의를 받은 뒤에만 진행합니다.',
    ),
    (
      '문의',
      '개인정보 관련 문의는 help@sphinfo.co.kr 로 연락 주세요.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 처리방침')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          for (final (title, body) in _sections) ...[
            Text(title,
                style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: scheme.primary)),
            const SizedBox(height: 6),
            Text(body, style: text.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
