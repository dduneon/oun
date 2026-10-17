import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/shared/api/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('판매 중인 상점 썸네일 18개가 512px 투명 PNG로 번들된다', () async {
    const keys = [
      'hood_daily',
      'tee_runner',
      'cardigan_knit',
      'tank_sleeveless',
      'windbreaker',
      'jogger_pants',
      'running_shorts',
      'leggings',
      'sneakers_run',
      'hightop',
      'rain_boots',
      'hair_ponytail',
      'hair_braids',
      'hair_flick',
      'hair_spiky',
      'cap_sports',
      'towel_gym',
      'earbuds',
    ];

    for (final key in keys) {
      final data = await rootBundle.load('assets/shop/$key.png');
      final bytes = data.buffer.asUint8List();
      // PNG IHDR color type 6 = RGBA. 카드 배경색이 비치려면 alpha가 필요하다.
      expect(bytes[25], 6, reason: '$key alpha channel');
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512, reason: key);
      expect(frame.image.height, 512, reason: key);
      final pixels = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final rgba = pixels!.buffer.asUint8List();
      var transparent = 0;
      var visible = 0;
      for (var i = 3; i < rgba.length; i += 4) {
        if (rgba[i] == 0) transparent++;
        if (rgba[i] > 200) visible++;
      }
      expect(
        transparent,
        greaterThan(512 * 512 * 0.1),
        reason: '$key 배경이 실제로 투명해야 한다',
      );
      expect(
        visible,
        greaterThan(512 * 512 * 0.1),
        reason: '$key 상품이 충분한 크기로 보여야 한다',
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('상점 응답의 장착 상태를 복원한다', () {
    final item = ShopItem.fromJson({
      'key': 'cap_sports',
      'category': 'prop',
      'name': '스포츠 캡',
      'price': 80,
      'owned': true,
      'equipped': true,
    });

    expect(item.owned, isTrue);
    expect(item.equipped, isTrue);
  });
}
