import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dates.dart';

/// O dia de hoje (meia-noite local). Muda sozinho à meia-noite e quando o
/// app volta para a tela, para que rotina e hábitos virem de dia.
class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  DateTime build() {
    _lifecycle = AppLifecycleListener(onResume: refresh);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });
    _scheduleMidnight();
    return dateOnly(DateTime.now());
  }

  void refresh() {
    final now = dateOnly(DateTime.now());
    if (now != state) state = now;
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), refresh);
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(
  TodayNotifier.new,
);
