import 'package:flutter/material.dart';

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
            // 여기에 나중에 Unity 캐릭터(UaaL)가 임베드됩니다.
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E9DF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE8D5C4)),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pets, size: 48, color: Color(0xFFC9A88C)),
                        SizedBox(height: 12),
                        Text(
                          '여기에 내 캐릭터가 나타납니다',
                          style: TextStyle(color: Color(0xFF9C8B7D)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '(다음 단계: Unity 임베드)',
                          style: TextStyle(fontSize: 12, color: Color(0xFFBBA99B)),
                        ),
                      ],
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
