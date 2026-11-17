import '../entities/insight.dart';
import '../entities/transaction.dart';
import 'insight_context.dart';
import 'insight_rule.dart';
import 'rules/spending_rules.dart';

/// Ejecuta todas las reglas y ordena por severidad y relevancia.
/// Determinista y 100% local: no necesita red ni modelos.
class InsightEngine {
  const InsightEngine(this.rules);

  factory InsightEngine.standard() => const InsightEngine([
        GettingStartedRule(),
        BudgetRule(),
        DuplicateChargeRule(),
        SavingsRule(),
        MonthComparisonRule(),
        CategorySpikeRule(),
        SubscriptionsRule(),
        AntExpensesRule(),
        DeliveryRule(),
        ProjectionRule(),
        TopMerchantRule(),
        WeekendRule(),
        NightSpendingRule(),
      ]);

  final List<InsightRule> rules;

  List<Insight> generate({
    required List<Transaction> transactions,
    Map<String, int> budgets = const {},
    int? expectedIncomeMinor,
    DateTime? now,
  }) {
    final ctx = InsightContext(
      now: now ?? DateTime.now(),
      transactions: transactions,
      budgets: budgets,
      expectedIncomeMinor: expectedIncomeMinor,
    );
    final out = <Insight>[];
    for (final rule in rules) {
      out.addAll(rule.evaluate(ctx));
    }
    out.sort((a, b) {
      final bySeverity = _weight(b.severity).compareTo(_weight(a.severity));
      if (bySeverity != 0) return bySeverity;
      return b.score.compareTo(a.score);
    });
    return out;
  }

  static int _weight(InsightSeverity s) => switch (s) {
        InsightSeverity.warning => 3,
        InsightSeverity.positive => 2,
        InsightSeverity.info => 1,
      };
}
