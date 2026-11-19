enum InsightSeverity { positive, info, warning }

enum InsightKind {
  monthComparison,
  categorySpike,
  subscriptions,
  antExpenses,
  budget,
  delivery,
  weekend,
  duplicateCharge,
  topMerchant,
  projection,
  savings,
  nightSpending,
  gettingStarted,
  backup,
}

/// Recomendación o hallazgo generado localmente a partir de los movimientos.
class Insight {
  const Insight({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.body,
    this.amountMinor,
    this.categoryId,
    this.score = 0,
  });

  final String id;
  final InsightKind kind;
  final InsightSeverity severity;
  final String title;
  final String body;
  final int? amountMinor;
  final String? categoryId;

  /// Relevancia relativa para ordenar (mayor primero).
  final double score;
}
