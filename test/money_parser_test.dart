import 'package:finaid/domain/parsing/money_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyParser.toMinor', () {
    test('formato colombiano con decimales', () {
      expect(MoneyParser.toMinor('45.900,00'), 4590000);
    });
    test('formato colombiano sin decimales', () {
      expect(MoneyParser.toMinor('45.900'), 4590000);
      expect(MoneyParser.toMinor('1.250.000'), 125000000);
    });
    test('formato inglés', () {
      expect(MoneyParser.toMinor('45,900'), 4590000);
      expect(MoneyParser.toMinor('1,250,000.50'), 125000050);
      expect(MoneyParser.toMinor('25.50'), 2550);
    });
    test('entero sin separadores', () {
      expect(MoneyParser.toMinor('100'), 10000);
    });
  });

  group('MoneyParser.parseFirst', () {
    test('encuentra el monto con símbolo', () {
      final m = MoneyParser.parseFirst(
          'Compra por \$45.900,00 en EXITO a las 14:33. 12/11/2026 *1234');
      expect(m, isNotNull);
      expect(m!.amountMinor, 4590000);
      expect(m.currency, 'COP');
    });

    test('ignora fechas, horas, tarjetas y referencias', () {
      expect(
        MoneyParser.parseFirst('12/11/2026 a las 14:33 *1234 Ref 123456'),
        isNull,
      );
    });

    test('acepta COP antes y pesos después', () {
      expect(MoneyParser.parseFirst('COP 45.900')!.amountMinor, 4590000);
      expect(MoneyParser.parseFirst('Compraste 45900 pesos')!.amountMinor,
          4590000);
    });

    test('detecta dólares', () {
      final m = MoneyParser.parseFirst('Compra aprobada: US\$12.99 en OPENAI');
      expect(m!.amountMinor, 1299);
      expect(m.currency, 'USD');
    });

    test('miles en estilo inglés (Nu)', () {
      expect(MoneyParser.parseFirst('Compra de \$1,250,000 aprobada')!.amountMinor,
          125000000);
    });

    test('devuelve el primero en orden de aparición', () {
      final m = MoneyParser.parseFirst(
          'Enviaste \$30.000 a Juan Perez. Tu saldo es \$120.000.');
      expect(m!.amountMinor, 3000000);
      expect(m.end, lessThan(20));
    });
  });
}
