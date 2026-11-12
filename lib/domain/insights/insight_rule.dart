import '../entities/insight.dart';
import 'insight_context.dart';

/// Una regla produce cero o más insights a partir del contexto.
abstract class InsightRule {
  const InsightRule();

  List<Insight> evaluate(InsightContext ctx);
}

/// Umbrales compartidos, en unidades menores (1 COP = 100).
class Thresholds {
  Thresholds._();

  static const int cop = 100;
  static const int antExpenseMax = 20000 * cop;
  static const int spikeMin = 50000 * cop;
  static const int weekendMin = 100000 * cop;
}
