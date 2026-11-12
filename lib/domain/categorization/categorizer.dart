import '../../core/utils/text_tools.dart';
import '../entities/category.dart';
import '../entities/merchant_rule.dart';
import '../entities/transaction.dart';
import 'keyword_rules.dart';

typedef CategoryDecision = ({String categoryId, CategorySource source});

/// Asigna categoría combinando, en orden de prioridad:
/// 1. reglas del usuario por comercio,
/// 2. el tipo de movimiento (ingresos, retiros),
/// 3. palabras clave del comercio,
/// 4. palabras clave del texto completo,
/// 5. tipo transferencia → "Transferencias",
/// 6. "Otros".
class Categorizer {
  const Categorizer(this.rules);

  factory Categorizer.standard() => const Categorizer(defaultKeywordRules);

  final List<KeywordRule> rules;

  CategoryDecision categorize({
    required TransactionKind kind,
    required String merchantKey,
    required String fullText,
    MerchantRule? merchantRule,
  }) {
    final ruleCategory = merchantRule?.categoryId;
    if (ruleCategory != null) {
      return (categoryId: ruleCategory, source: CategorySource.merchantRule);
    }
    if (kind.isIncome) {
      return (categoryId: Categories.ingresos.id, source: CategorySource.kind);
    }
    if (kind == TransactionKind.withdrawal) {
      return (categoryId: Categories.retiros.id, source: CategorySource.kind);
    }

    final byMerchant = matchKeywords(merchantKey);
    if (byMerchant != null) {
      return (categoryId: byMerchant, source: CategorySource.keywordRule);
    }
    if (kind == TransactionKind.billPayment || merchantKey.isEmpty) {
      final byText = matchKeywords(TextTools.merchantKey(fullText));
      if (byText != null) {
        return (categoryId: byText, source: CategorySource.keywordRule);
      }
    }
    if (kind == TransactionKind.transferOut) {
      return (
        categoryId: Categories.transferencias.id,
        source: CategorySource.kind
      );
    }
    return (categoryId: Categories.otros.id, source: CategorySource.fallback);
  }

  /// [normalizedUpper] debe venir en formato `TextTools.merchantKey`.
  String? matchKeywords(String normalizedUpper) {
    if (normalizedUpper.isEmpty) return null;
    final padded = ' $normalizedUpper ';
    for (final rule in rules) {
      for (final kw in rule.keywords) {
        if (padded.contains(' $kw')) return rule.categoryId;
      }
    }
    return null;
  }
}
