import 'package:flutter/material.dart';

/// 사진 원본을 전체 화면 팝업으로 띄운다. 핀치 줌 가능, 배경/닫기 버튼/탭으로 닫힘.
void showPhotoViewer(BuildContext context, String url) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _PhotoViewer(url: url),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 전체 화면을 꽉 채우지 않고 여백을 둔 채 카드처럼 띄운다.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // 사진 바깥(어두운 영역)을 탭하면 닫힌다.
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width - 40,
                  maxHeight: size.height * 0.78,
                ),
                child: GestureDetector(
                  onTap: () {}, // 사진 위 탭은 닫기로 전달되지 않게 흡수(줌 위해)
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const SizedBox(
                                    width: 120,
                                    height: 120,
                                    child: Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.white70)),
                                  ),
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 120,
                          height: 120,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white54, size: 44),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 6,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                tooltip: '닫기',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
