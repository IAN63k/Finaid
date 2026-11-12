class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.isExpense = true,
  });

  final String id;
  final String name;
  final String emoji;

  /// ARGB. Se mantiene como int para que el dominio no dependa de Flutter.
  final int color;
  final bool isExpense;
}

class Categories {
  Categories._();

  static const mercado =
      Category(id: 'mercado', name: 'Mercado', emoji: '🛒', color: 0xFF2E7D32);
  static const restaurantes = Category(
      id: 'restaurantes',
      name: 'Restaurantes y domicilios',
      emoji: '🍔',
      color: 0xFFEF6C00);
  static const transporte = Category(
      id: 'transporte', name: 'Transporte', emoji: '🚗', color: 0xFF1565C0);
  static const hogar = Category(
      id: 'hogar', name: 'Hogar y servicios', emoji: '🏠', color: 0xFF6D4C41);
  static const suscripciones = Category(
      id: 'suscripciones',
      name: 'Suscripciones',
      emoji: '📺',
      color: 0xFF7B1FA2);
  static const salud =
      Category(id: 'salud', name: 'Salud', emoji: '💊', color: 0xFFC62828);
  static const compras =
      Category(id: 'compras', name: 'Compras', emoji: '🛍️', color: 0xFFAD1457);
  static const educacion = Category(
      id: 'educacion', name: 'Educación', emoji: '📚', color: 0xFF00838F);
  static const viajes =
      Category(id: 'viajes', name: 'Viajes', emoji: '✈️', color: 0xFF0277BD);
  static const entretenimiento = Category(
      id: 'entretenimiento',
      name: 'Entretenimiento',
      emoji: '🎬',
      color: 0xFF5E35B1);
  static const transferencias = Category(
      id: 'transferencias',
      name: 'Transferencias',
      emoji: '🔁',
      color: 0xFF455A64);
  static const retiros =
      Category(id: 'retiros', name: 'Retiros', emoji: '🏧', color: 0xFF37474F);
  static const otros =
      Category(id: 'otros', name: 'Otros', emoji: '📦', color: 0xFF757575);
  static const ingresos = Category(
      id: 'ingresos',
      name: 'Ingresos',
      emoji: '💰',
      color: 0xFF00897B,
      isExpense: false);

  static const List<Category> all = [
    mercado,
    restaurantes,
    transporte,
    hogar,
    suscripciones,
    salud,
    compras,
    educacion,
    viajes,
    entretenimiento,
    transferencias,
    retiros,
    otros,
    ingresos,
  ];

  static List<Category> get expenses =>
      all.where((c) => c.isExpense).toList(growable: false);

  static Category byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => otros);
}
