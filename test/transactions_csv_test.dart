import 'package:finaid/domain/entities/transaction.dart';
import 'package:finaid/domain/export/transactions_csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fixtures.dart';

void main() {
  test('CSV para Excel en español: BOM, punto y coma y signos', () {
    final csv = TransactionsCsv.build([
      tx(cop: 50, at: DateTime(2026, 11, 17, 0, 2), kind: TransactionKind.transferIn, merchant: 'KAROL', category: 'ingresos', bank: 'nequi'),
      tx(cop: 26190, at: DateTime(2026, 11, 17, 0, 39), merchant: 'AGC TECNOLOGIA', category: 'compras', bank: 'bbva'),
    ]);
    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.substring(1).split('\r\n')..removeLast();
    expect(lines.first, TransactionsCsv.header.join(';'));
    expect(lines[1],
        '2026-11-17;00:02;Transferencia recibida;KAROL;Ingresos;Nequi;;50;COP;No;');
    expect(lines[2],
        '2026-11-17;00:39;Compra;AGC TECNOLOGIA;Compras;BBVA;;-26190;COP;No;');
  });

  test('ordena por fecha y escribe centavos con coma', () {
    final t = tx(cop: 0, at: DateTime(2026, 11, 2), merchant: 'B')
        .copyWith(amountMinor: 1299, currency: 'USD');
    final csv = TransactionsCsv.build([
      tx(cop: 10, at: DateTime(2026, 11, 3), merchant: 'C'),
      t,
    ]);
    final lines = csv.substring(1).split('\r\n');
    expect(lines[1], contains(';-12,99;USD;'));
    expect(lines[2], startsWith('2026-11-03'));
  });

  test('escapa separadores y comillas, y neutraliza fórmulas', () {
    final csv = TransactionsCsv.build([
      tx(cop: 1, at: DateTime(2026, 11, 1), merchant: 'PAN; LECHE "Y" MAS'),
      tx(cop: 1, at: DateTime(2026, 11, 2), merchant: '=HYPERLINK("x")'),
      tx(cop: 1, at: DateTime(2026, 11, 3), merchant: 'OK', ignored: true),
    ]);
    expect(csv, contains('"PAN; LECHE ""Y"" MAS"'));
    expect(csv, contains("'=HYPERLINK(\"\"x\"\")"));
    expect(csv, isNot(contains(';=HYPERLINK')));
    expect(csv, contains(';Sí;'));
  });
}
