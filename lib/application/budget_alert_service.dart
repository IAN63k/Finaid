import '../domain/budgets/budget_check.dart';
import '../domain/entities/transaction.dart';
import '../domain/ports/repositories.dart';

/// Calcula cómo queda el presupuesto de la categoría de un gasto recién
/// registrado, leyendo los movimientos y presupuestos guardados.
class BudgetAlertService {
  BudgetAlertService({required this.transactions, required this.budgets});

  final TransactionRepository transactions;
  final BudgetRepository budgets;

  Future<BudgetCheck?> check(Transaction transaction, {DateTime? now}) async {
    if (!transaction.countsAsExpense) return null;
    final limits = await budgets.all();
    if (!limits.containsKey(transaction.categoryId)) return null;
    return BudgetEvaluator.evaluate(
      transaction: transaction,
      all: await transactions.all(),
      budgets: limits,
      now: now,
    );
  }
}
