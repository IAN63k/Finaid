import 'package:flutter/widgets.dart';

/// Logo de Finaid: una "F" blanca con un punto ámbar de notificación sobre un
/// cuadrado redondeado verde azulado. Misma geometría que el ícono adaptativo
/// de Android (lienzo de 108 × 108) y que docs/brand/finaid-logo.svg.
class FinaidLogo extends StatelessWidget {
  const FinaidLogo({super.key, this.size = 48});

  final double size;

  static const Color tealLight = Color(0xFF14A58C);
  static const Color tealDark = Color(0xFF0A4F45);
  static const Color amber = Color(0xFFFFC24B);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Finaid',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _FinaidLogoPainter()),
      ),
    );
  }
}

class _FinaidLogoPainter extends CustomPainter {
  const _FinaidLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 108, size.height / 108);

    const rect = Rect.fromLTWH(0, 0, 108, 108);
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [FinaidLogo.tealLight, FinaidLogo.tealDark],
      ).createShader(rect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(24)), background);

    // La marca se dibuja en la zona segura del ícono adaptativo y se amplía
    // 1,3× alrededor del centro para el ícono plano.
    canvas.translate(54, 54);
    canvas.scale(1.3);
    canvas.translate(-54, -54);

    final white = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRRect(
        RRect.fromLTRBR(34, 32, 44, 76, const Radius.circular(5)), white);
    canvas.drawRRect(
        RRect.fromLTRBR(34, 32, 59, 42, const Radius.circular(5)), white);
    canvas.drawRRect(
        RRect.fromLTRBR(34, 50, 56, 59, const Radius.circular(4.5)), white);
    canvas.drawCircle(
        const Offset(68.5, 37), 6, Paint()..color = FinaidLogo.amber);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
