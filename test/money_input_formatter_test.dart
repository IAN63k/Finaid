import 'package:finaid/presentation/widgets/money_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _v(String text, [int? cursor]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );

void main() {
  const f = MoneyInputFormatter();

  group('formato y lectura', () {
    test('agrupa miles con punto', () {
      expect(MoneyInputFormatter.format('5'), '5');
      expect(MoneyInputFormatter.format('1500'), '1.500');
      expect(MoneyInputFormatter.format('1500000'), '1.500.000');
      expect(MoneyInputFormatter.format('123456789'), '123.456.789');
    });

    test('parse y fromPesos', () {
      expect(MoneyInputFormatter.parse('1.500.000'), 1500000);
      expect(MoneyInputFormatter.parse(''), isNull);
      expect(MoneyInputFormatter.fromPesos(2500000), '2.500.000');
      expect(MoneyInputFormatter.fromPesos(null), '');
      expect(MoneyInputFormatter.fromPesos(0), '');
    });
  });

  group('mientras se escribe', () {
    test('al escribir al final agrega los puntos y deja el cursor al final', () {
      final r = f.formatEditUpdate(_v('150.000'), _v('150.0000'));
      expect(r.text, '1.500.000');
      expect(r.selection.baseOffset, r.text.length);
    });

    test('ignora letras y símbolos pegados', () {
      final r = f.formatEditUpdate(_v(''), _v('\$ 45,900 COP'));
      expect(r.text, '45.900');
    });

    test('quita ceros a la izquierda', () {
      expect(f.formatEditUpdate(_v(''), _v('0')).text, '');
      expect(f.formatEditUpdate(_v(''), _v('007')).text, '7');
    });

    test('insertar en medio conserva el cursor junto al dígito escrito', () {
      // "1.000" con el cursor después del 1; se escribe un 2 → "12.000".
      final r = f.formatEditUpdate(_v('1.000', 1), _v('12.000', 2));
      expect(r.text, '12.000');
      expect(r.selection.baseOffset, 2);
    });

    test('borrar un punto borra el dígito anterior', () {
      // "1.500" con el cursor después del punto; backspace quita el punto.
      final r = f.formatEditUpdate(_v('1.500', 2), _v('1500', 1));
      expect(r.text, '500');
      expect(r.selection.baseOffset, 0);
    });

    test('borrar el último dígito reagrupa', () {
      final r = f.formatEditUpdate(_v('1.500.000'), _v('1.500.00'));
      expect(r.text, '150.000');
      expect(r.selection.baseOffset, r.text.length);
    });

    test('respeta el máximo de dígitos', () {
      const small = MoneyInputFormatter(maxDigits: 4);
      final old = _v('9.999');
      expect(small.formatEditUpdate(old, _v('9.9999')), old);
    });
  });

  testWidgets('en un TextField muestra el separador al escribir', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          controller: controller,
          inputFormatters: const [MoneyInputFormatter()],
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), '2500000');
    expect(controller.text, '2.500.000');
    expect(MoneyInputFormatter.parse(controller.text), 2500000);
  });
}
