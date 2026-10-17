import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 오운이(사용자 캐릭터)의 겉모습. 서버 장착 상태(슬롯 → 아이템 키)와 성별로 정해진다.
///
/// 레이어 PNG는 art/character/oun_villager.blend 에서 같은 카메라·같은 캔버스로
/// 렌더한 것(art/character/render_layers.py)이라 그대로 겹치면 맞물린다.
class CharacterLook {
  const CharacterLook({required this.gender, this.equipment = const {}});

  /// 'm' | 'f'. 얼굴(여자는 body_f*)과 기본 머리(남자 short, 여자 down)를 정한다.
  final String gender;

  /// 슬롯(clothing·bottom·shoes·hair·prop) → 장착 아이템 키. clothing = 상의.
  final Map<String, String> equipment;

  bool get _female => gender == 'f';

  static const _tops = {
    'hood_daily',
    'tee_runner',
    'cardigan_knit',
    'tank_sleeveless',
    'windbreaker',
  };
  static const _bottoms = {'jogger_pants', 'running_shorts', 'leggings'};
  static const _shoes = {'sneakers_run', 'hightop', 'rain_boots'};
  static const _props = {'cap_sports', 'towel_gym', 'earbuds'};

  String get _top {
    final key = equipment['clothing'];
    return _tops.contains(key) ? 'top_$key' : 'top_basic';
  }

  String get _bottom {
    final key = equipment['bottom'];
    return _bottoms.contains(key) ? 'bottom_$key' : 'bottom_basic';
  }

  String get _shoe {
    final key = equipment['shoes'];
    return _shoes.contains(key) ? 'shoes_$key' : 'shoes_basic';
  }

  static const _hairs = {'hair_ponytail', 'hair_braids', 'hair_flick', 'hair_spiky'};

  /// 상점 헤어(레이어 이름 = 아이템 키), 없으면 성별 기본 머리.
  /// 모자를 쓰면 모자 밖으로 삐져나오지 않게 눌린 변형(_cap)을 쓴다.
  String get _hair {
    final key = equipment['hair'];
    final hair = _hairs.contains(key)
        ? key!
        : (_female ? 'hair_down' : 'hair_short');
    return _prop == 'prop_cap_sports' ? '${hair}_cap' : hair;
  }

  /// 표정별 몸(얼굴 포함) 레이어.
  String body(CharacterFace face) {
    final base = _female ? 'body_f' : 'body';
    return switch (face) {
      CharacterFace.normal => base,
      CharacterFace.blink => '${base}_blink',
      CharacterFace.happy => '${base}_happy',
    };
  }

  String? get _prop {
    final key = equipment['prop'];
    return _props.contains(key) ? 'prop_$key' : null;
  }

  /// 아래에서 위로 그릴 레이어(몸 제외).
  List<String> get overlayLayers => [
    _shoe,
    _bottom,
    _top,
    if (_prop == 'prop_towel_gym') _prop!,
    _hair,
    if (_prop == 'prop_earbuds' || _prop == 'prop_cap_sports') _prop!,
  ];

  static String asset(String layer) => 'assets/character/$layer.png';

  @override
  bool operator ==(Object other) =>
      other is CharacterLook &&
      other.gender == gender &&
      other._top == _top &&
      other._bottom == _bottom &&
      other._shoe == _shoe &&
      other._hair == _hair &&
      other._prop == _prop;

  @override
  int get hashCode => Object.hash(gender, _top, _bottom, _shoe, _hair, _prop);
}

/// 얼굴 표정. 몸 레이어에 얼굴이 함께 그려져 있어 몸 PNG를 바꿔 끼운다.
enum CharacterFace { normal, blink, happy }

/// 캔버스 비율(렌더 800×1000).
const double kCharacterAspect = 0.8;

/// 정지 상태의 캐릭터 한 명(그림자 + 레이어).
class CharacterFigure extends StatelessWidget {
  const CharacterFigure({
    super.key,
    required this.look,
    this.face = CharacterFace.normal,
    this.shadow = true,
  });

  final CharacterLook look;
  final CharacterFace face;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kCharacterAspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (shadow) const _GroundShadow(),
          _layer(look.body(face)),
          for (final l in look.overlayLayers) _layer(l),
        ],
      ),
    );
  }

  Widget _layer(String name) => Image.asset(
    CharacterLook.asset(name),
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    // 표정·옷을 바꿔 끼울 때 한 프레임 비는 깜빡임을 막는다.
    gaplessPlayback: true,
  );
}

class _GroundShadow extends StatelessWidget {
  const _GroundShadow();

  @override
  Widget build(BuildContext context) {
    // 신발 밑(캔버스 아래 6%)에 납작한 타원 그림자.
    return Align(
      alignment: const Alignment(0, 0.9),
      child: FractionallySizedBox(
        widthFactor: 0.46,
        heightFactor: 0.07,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(
              colors: [
                const Color(0xFF8A6E5E).withValues(alpha: 0.26),
                const Color(0xFF8A6E5E).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 홈 캐릭터에게 반응을 재생시키는 신호. 값이 바뀔 때마다 한 번 반응한다.
class CharacterReactionController extends Notifier<int> {
  @override
  int build() => 0;

  void play() => state++;
}

final characterReactionProvider =
    NotifierProvider<CharacterReactionController, int>(
      CharacterReactionController.new,
    );

/// 살아 있는 캐릭터: 숨쉬기, 가끔 깜빡임, 탭하거나 [characterReactionProvider]가
/// 울리면 폴짝 뛰며 활짝 웃는다.
class LivingCharacter extends ConsumerStatefulWidget {
  const LivingCharacter({
    super.key,
    required this.look,
    this.reactToProvider = false,
    this.seed = 0,
  });

  final CharacterLook look;

  /// 홈 캐릭터만 true — 전역 반응 신호를 듣는다.
  final bool reactToProvider;

  /// 여러 명이 함께 있을 때 숨쉬기·깜빡임 박자가 어긋나도록.
  final int seed;

  @override
  ConsumerState<LivingCharacter> createState() => _LivingCharacterState();
}

class _LivingCharacterState extends ConsumerState<LivingCharacter>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _hop;
  late final math.Random _rng;
  Timer? _blinkTimer;
  bool _blinking = false;

  @override
  void initState() {
    super.initState();
    _rng = math.Random(widget.seed);
    _breath = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2600 + widget.seed % 5 * 180),
    )..repeat();
    _breath.value = (widget.seed * 0.37) % 1.0;
    _hop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scheduleBlink();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 표정 PNG를 미리 올려 두어 처음 깜빡일 때 비지 않게 한다.
    for (final f in [CharacterFace.blink, CharacterFace.happy]) {
      precacheImage(
        AssetImage(CharacterLook.asset(widget.look.body(f))),
        context,
      );
    }
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2200 + _rng.nextInt(3200)),
      () async {
        if (!mounted) return;
        setState(() => _blinking = true);
        await Future<void>.delayed(const Duration(milliseconds: 130));
        if (!mounted) return;
        setState(() => _blinking = false);
        _scheduleBlink();
      },
    );
  }

  void _react() {
    if (_hop.isAnimating) return;
    _hop.forward(from: 0);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _breath.dispose();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reactToProvider) {
      ref.listen<int>(characterReactionProvider, (prev, next) {
        if (prev != next) _react();
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _react,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _hop]),
        builder: (context, _) {
          final t = _breath.value * 2 * math.pi;
          final h = _hop.value;
          // 폴짝: 움츠렸다가(0~0.18) 뛰어올랐다(0.18~0.62) 착지 후 출렁(0.62~1).
          // stretch > 0 이면 세로로 늘어나고, < 0 이면 납작해진다.
          double lift = 0, stretch = 0;
          if (h > 0 && h < 1) {
            if (h < 0.18) {
              stretch = -math.sin(h / 0.18 * math.pi) * 0.07;
            } else if (h < 0.62) {
              final p = (h - 0.18) / 0.44;
              lift = math.sin(p * math.pi);
              stretch = math.sin(p * math.pi) * 0.04;
            } else {
              final p = (h - 0.62) / 0.38;
              stretch = -math.sin(p * math.pi * 2) * 0.05 * (1 - p);
            }
          }
          final breathe = math.sin(t) * 0.012;
          final sway = math.sin(t * 0.5) * 0.012;
          final face = (h > 0 && h < 1)
              ? CharacterFace.happy
              : (_blinking ? CharacterFace.blink : CharacterFace.normal);

          return LayoutBuilder(
            builder: (context, c) {
              final height = c.maxHeight.isFinite ? c.maxHeight : 300.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 그림자는 땅에 붙어 있고, 뛰면 작아진다.
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 1 - lift * 0.25,
                      child: const AspectRatio(
                        aspectRatio: kCharacterAspect,
                        child: _GroundShadow(),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, -lift * height * 0.09),
                      child: Transform(
                        alignment: const Alignment(0, 0.86),
                        transform: Matrix4.identity()
                          ..rotateZ(sway)
                          ..scaleByDouble(
                            1 - (stretch + breathe) * 0.6,
                            1 + stretch + breathe,
                            1,
                            1,
                          ),
                        child: CharacterFigure(
                          look: widget.look,
                          face: face,
                          shadow: false,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
