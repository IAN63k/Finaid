import 'package:finaid/domain/categorization/categorizer.dart';
import 'package:finaid/domain/categorization/keyword_rules.dart';
import 'package:finaid/domain/entities/merchant_rule.dart';
import 'package:finaid/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final categorizer = Categorizer.standard();

  CategoryDecision run(String merchantKey,
      {TransactionKind kind = TransactionKind.purchase,
      String fullText = '',
      MerchantRule? rule}) {
    return categorizer.categorize(
      kind: kind,
      merchantKey: merchantKey,
      fullText: fullText,
      merchantRule: rule,
    );
  }

  test('las reglas apuntan a categorías existentes', () {
    expect(keywordRulesAreConsistent(defaultKeywordRules), isTrue);
  });

  test('comercios colombianos frecuentes', () {
    expect(run('EXITO CALLE 80').categoryId, 'mercado');
    expect(run('RAPPI').categoryId, 'restaurantes');
    expect(run('NETFLIX COM').categoryId, 'suscripciones');
    expect(run('TERPEL AUTOPISTA').categoryId, 'transporte');
    expect(run('FARMATODO 123').categoryId, 'salud');
    expect(run('CLARO').categoryId, 'hogar');
    expect(run('AVIANCA').categoryId, 'viajes');
    expect(run('CINE COLOMBIA').categoryId, 'entretenimiento');
  });

  test('UBER EATS es restaurante, UBER TRIP es transporte', () {
    expect(run('UBER EATS').categoryId, 'restaurantes');
    expect(run('UBER TRIP').categoryId, 'transporte');
  });

  test('el tipo de movimiento manda para ingresos y retiros', () {
    expect(run('MARIA LOPEZ', kind: TransactionKind.transferIn).categoryId,
        'ingresos');
    expect(run('NOMINA EMPRESA', kind: TransactionKind.deposit).categoryId,
        'ingresos');
    expect(run('CAJERO SERVIBANCA', kind: TransactionKind.withdrawal).categoryId,
        'retiros');
  });

  test('transferencias a personas van a Transferencias', () {
    final d = run('JUAN PEREZ', kind: TransactionKind.transferOut);
    expect(d.categoryId, 'transferencias');
    expect(d.source, CategorySource.kind);
  });

  test('sin coincidencias cae en Otros', () {
    final d = run('XYZ COMERCIO RARO');
    expect(d.categoryId, 'otros');
    expect(d.source, CategorySource.fallback);
  });

  test('pago de factura usa el texto completo cuando no hay comercio', () {
    final d = run('',
        kind: TransactionKind.billPayment,
        fullText: 'Pago de factura EPM por \$120.000 realizado');
    expect(d.categoryId, 'hogar');
  });

  test('la regla del usuario tiene prioridad', () {
    final rule = MerchantRule(
      id: 'r1',
      merchantKey: 'RAPPI',
      categoryId: 'compras',
      createdAt: DateTime(2026),
    );
    final d = run('RAPPI', rule: rule);
    expect(d.categoryId, 'compras');
    expect(d.source, CategorySource.merchantRule);
  });
}
