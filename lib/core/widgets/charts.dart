import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gráfico de linha simples (evolução de um valor ao longo do tempo).
///
/// Desenhado no próprio app, sem biblioteca externa. A linha tracejada
/// opcional mostra uma meta.
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.values,
    this.goal,
    this.height = 160,
    this.format,
    this.startLabel,
    this.endLabel,
  });

  final List<double> values;
  final double? goal;
  final double height;
  final String Function(double value)? format;
  final String? startLabel;
  final String? endLabel;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    var min = values.reduce((a, b) => a < b ? a : b);
    var max = values.reduce((a, b) => a > b ? a : b);
    if (goal != null) {
      if (goal! < min) min = goal!;
      if (goal! > max) max = goal!;
    }
    if (max == min) {
      max += 1;
      min -= 1;
    }
    final fmt = format ?? (double v) => v.toStringAsFixed(1);
    const labelStyle = TextStyle(fontSize: 11, color: AppColors.textFaint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmt(max), style: labelStyle),
                  Text(fmt(min), style: labelStyle),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomPaint(
                  painter: _LinePainter(
                    values: values,
                    min: min,
                    max: max,
                    goal: goal,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (startLabel != null || endLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(startLabel ?? '', style: labelStyle),
                Text(endLabel ?? '', style: labelStyle),
              ],
            ),
          ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.min,
    required this.max,
    required this.goal,
  });

  final List<double> values;
  final double min;
  final double max;
  final double? goal;

  @override
  void paint(Canvas canvas, Size size) {
    double y(double v) =>
        size.height - (v - min) / (max - min) * (size.height - 8) - 4;
    double x(int i) => values.length == 1
        ? size.width / 2
        : i / (values.length - 1) * (size.width - 8) + 4;

    final grid = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), grid);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      grid,
    );

    if (goal != null) {
      final goalPaint = Paint()
        ..color = AppColors.textMuted
        ..strokeWidth = 1.5;
      final gy = y(goal!);
      for (var dx = 0.0; dx < size.width; dx += 10) {
        canvas.drawLine(Offset(dx, gy), Offset(dx + 5, gy), goalPaint);
      }
    }

    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = AppColors.primary;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i])), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.min != min ||
      old.max != max ||
      old.goal != goal;
}

/// Uma barra do [SimpleBarChart]: rótulo e fatias empilhadas (valor, cor).
class BarData {
  const BarData(this.label, this.segments);

  final String label;
  final List<(double, Color)> segments;

  double get total => segments.fold(0, (sum, s) => sum + s.$1);
}

/// Gráfico de barras (empilhadas) feito só com widgets.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.bars, this.height = 120});

  final List<BarData> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<double>(0, (m, b) => b.total > m ? b.total : m);
    return SizedBox(
      height: height + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (max > 0)
                      for (final (value, color) in bar.segments.reversed)
                        if (value > 0)
                          Container(
                            height: value / max * height,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                    if (bar.total == 0)
                      Container(height: 2, color: AppColors.outline),
                    const SizedBox(height: 4),
                    Text(
                      bar.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
