import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';

void main() {
  runApp(const OunApp());
}

class OunApp extends StatelessWidget {
  const OunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '오운',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE8A87C), // 오운 웜톤
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFdF6F0),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '오운',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5C4033),
                    ),
                  ),
                  Icon(Icons.settings_outlined, color: Color(0xFF5C4033)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '오늘의 운동, 나만의 속도로 귀엽게 차곡차곡',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9C8B7D)),
                ),
              ),
            ),
            // 홈의 캐릭터 무대: Unity(UaaL) 3D 씬을 임베드
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: const Color(0xFFF3E9DF),
                    child: EmbedUnity(
                      onMessageFromUnity: (String message) {
                        // Unity → Flutter 메시지 수신 (추후 상호작용에 사용)
                        debugPrint('Unity → Flutter: $message');
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A87C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    '오늘 운동 기록하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
