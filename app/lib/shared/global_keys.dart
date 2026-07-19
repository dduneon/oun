import 'package:flutter/material.dart';

/// 앱 전역 ScaffoldMessenger 키. context 없이(예: Unity 메시지 콜백)
/// 토스트를 띄울 때 사용한다.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();
