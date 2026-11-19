import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart';
import '../../core/utils/money_format.dart';
import '../../domain/analytics/monthly_trends.dart';

/// Barras de gasto por mes, dibujadas a mano (sin dependencias).
///
/// Reglas de la guía de visualización: una sola serie y un solo eje; barras
/// delgadas con extremo redondeado de 4 px apoyadas en la base; 2 px de aire
/// entre barras; rejilla y ejes discretos; el promedio como línea punteada; el
/// mes en curso con relleno rayado (datos parciales) en vez de otro color; los
/// textos en tonos de texto, nunca en el color de la serie. Tocar una barra la
/// selecciona y muestra su valor.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({
    super.key,
    required this.points,
    required this.averageMinor,
    required this.selectedIndex,
    required this.onSelect,
    this.height = 220,
  });

  final List<MonthPoint> points;
  final int averageMinor;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double height;

  static const double leftAxis = 44;
  static const double bottomAxis = 28;
  static const double topPad = 28;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Gráfico de gasto por mes. '
          '${points.map((p) => '${Dates.monthLabel(p.month)}: ${MoneyFormat.format(p.expensesMinor)}').join('. ')}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _select(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) => _select(d.localPosition.dx, width),
            child: CustomPaint(
              size: Size(width, height),
              painter: _BarsPainter(
                points: points,
                averageMinor: averageMinor,
                selectedIndex: selectedIndex,
                bar: scheme.primary,
                barDim: scheme.primary.withAlpha(90),
                grid: scheme.outlineVariant.withAlpha(120),
                ink: scheme.onSurface,
                inkMuted: scheme.onSurfaceVariant,
                tooltipFill: scheme.inverseSurface,
                tooltipInk: scheme.onInverseSurface,
                surface: scheme.surface,
                labelStyle: text.labelSmall ?? const TextStyle(fontSize: 11),
              ),
            ),
          );
        },
      ),
    );
  }

  void _select(double dx, double width) {
    final plot = width - leftAxis;
    if (plot <= 0 || points.isEmpty) return;
    final slot = plot / points.length;
    final index =
        ((dx - leftAxis) / slot).floor().clamp(0, points.length - 1).toInt();
    if (index != selectedIndex) onSelect(index);
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.points,
    required this.averageMinor,
    required this.selectedIndex,
    required this.bar,
    required this.barDim,
    required this.grid,
    required this.ink,
    required this.inkMuted,
    required this.tooltipFill,
    required this.tooltipInk,
    required this.surface,
    required this.labelStyle,
  });

  final List<MonthPoint> points;
  final int averageMinor;
  final int selectedIndex;
  final Color bar;
  final Color barDim;
  final Color grid;
  final Color ink;
  final Color inkMuted;
  final Color tooltipFill;
  final Color tooltipInk;
  final Color surface;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = MonthlyBarChart.leftAxis;
    const bottom = MonthlyBarChart.bottomAxis;
    const top = MonthlyBarChart.topPad;
    final plotW = size.width - left;
    final plotH = size.height - bottom - top;
    if (plotW <= 0 || plotH <= 0 || points.isEmpty) return;

    final maxValue = points.fold<int>(
        math.max(averageMinor, 1), (m, p) => math.max(m, p.expensesMinor));
    final niceMax = _niceCeil(maxValue);
    double y(int v) => top + plotH - (v / niceMax) * plotH;

    // Rejilla y etiquetas del eje Y (3 líneas, discretas).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final v = (niceMax * i / 3).round();
      final gy = y(v);
      canvas.drawLine(Offset(left, gy), Offset(size.width, gy), gridPaint);
      _text(canvas, MoneyFormat.compact(v), Offset(left - 6, gy),
          color: inkMuted, align: _Align.rightMiddle);
    }

    // Barras.
    final slot = plotW / points.length;
    final barW = math.min(28.0, slot - 2).clamp(4.0, 28.0).toDouble();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = left + slot * i + slot / 2;
      final selected = i == selectedIndex;
      final color = selected ? bar : barDim;
      final h = (p.expensesMinor / niceMax) * plotH;
      if (h > 0) {
        final rect = Rect.fromLTWH(cx - barW / 2, top + plotH - h, barW, h);
        final rrect = RRect.fromRectAndCorners(rect,
            topLeft: const Radius.circular(4), topRight: const Radius.circular(4));
        if (p.isCurrent) {
          // Mes en curso: contorno + rayado (datos parciales), mismo tono.
          canvas.save();
          canvas.clipRRect(rrect);
          canvas.drawRRect(rrect, Paint()..color = color.withAlpha(selected ? 70 : 40));
          final hatch = Paint()
            ..color = color
            ..strokeWidth = 2;
          for (var d = -h; d < barW + h; d += 6) {
            canvas.drawLine(Offset(rect.left + d, rect.bottom),
                Offset(rect.left + d + h, rect.bottom - h), hatch);
          }
          canvas.restore();
          canvas.drawRRect(
              rrect,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2);
        } else {
          canvas.drawRRect(rrect, Paint()..color = color);
        }
      }

      // Mes debajo de la barra.
      final name = Dates.monthNamesEs[p.month.month - 1].substring(0, 3);
      _text(canvas, p.isCurrent ? '$name*' : name,
          Offset(cx, size.height - bottom + 6),
          color: selected ? ink : inkMuted,
          bold: selected,
          align: _Align.topCenter);
    }

    // Promedio: línea punteada con etiqueta.
    if (averageMinor > 0) {
      final ay = y(averageMinor);
      final dash = Paint()
        ..color = inkMuted
        ..strokeWidth = 1.5;
      for (var x = left; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, ay), Offset(math.min(x + 4, size.width), ay), dash);
      }
      _text(canvas, 'prom.', Offset(size.width, ay - 2),
          color: inkMuted, align: _Align.rightBottom);
    }

    // Valor de la barra seleccionada.
    if (selectedIndex >= 0 && selectedIndex < points.length) {
      final p = points[selectedIndex];
      final cx = left + slot * selectedIndex + slot / 2;
      final barTop = y(p.expensesMinor);
      final label = MoneyFormat.compact(p.expensesMinor);
      final tp = _layout(label, color: tooltipInk, bold: true);
      const padH = 8.0, padV = 4.0;
      final w = tp.width + padH * 2;
      final hgt = tp.height + padV * 2;
      final bx = (cx - w / 2).clamp(left, math.max(left, size.width - w)).toDouble();
      final by = math.max(0.0, barTop - hgt - 6);
      final box = RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, w, hgt), const Radius.circular(6));
      canvas.drawRRect(box, Paint()..color = tooltipFill);
      tp.paint(canvas, Offset(bx + padH, by + padV));
    }
  }

  TextPainter _layout(String s, {required Color color, bool bold = false}) =>
      TextPainter(
        text: TextSpan(
            text: s,
            style: labelStyle.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()])),
        textDirection: TextDirection.ltr,
      )..layout();

  void _text(Canvas canvas, String s, Offset at,
      {required Color color, bool bold = false, required _Align align}) {
    final tp = _layout(s, color: color, bold: bold);
    final offset = switch (align) {
      _Align.rightMiddle => Offset(at.dx - tp.width, at.dy - tp.height / 2),
      _Align.rightBottom => Offset(at.dx - tp.width, at.dy - tp.height),
      _Align.topCenter => Offset(at.dx - tp.width / 2, at.dy),
    };
    tp.paint(canvas, offset);
  }

  /// Techo "redondo" para el eje: 1, 2, 2,5 o 5 × 10ⁿ.
  static int _niceCeil(int value) {
    if (value <= 0) return 1;
    final exp = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (value <= m * exp) return (m * exp).ceil();
    }
    return (10 * exp).ceil();
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) =>
      old.points != points ||
      old.selectedIndex != selectedIndex ||
      old.averageMinor != averageMinor ||
      old.bar != bar;
}

enum _Align { rightMiddle, rightBottom, topCenter }
