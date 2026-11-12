/// Regla aprendida del usuario para un comercio: categoría fija y/o ignorar.
class MerchantRule {
  const MerchantRule({
    required this.id,
    required this.merchantKey,
    required this.createdAt,
    this.categoryId,
    this.ignore = false,
  });

  final String id;
  final String merchantKey;
  final String? categoryId;
  final bool ignore;
  final DateTime createdAt;

  MerchantRule copyWith({String? categoryId, bool? ignore}) => MerchantRule(
        id: id,
        merchantKey: merchantKey,
        createdAt: createdAt,
        categoryId: categoryId ?? this.categoryId,
        ignore: ignore ?? this.ignore,
      );
}
