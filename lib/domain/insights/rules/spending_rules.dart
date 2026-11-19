import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/utils/text_tools.dart';
import '../../entities/category.dart';
import '../../entities/insight.dart';
import '../../entities/transaction.dart';
import '../insight_context.dart';
import '../insight_rule.dart';

String _money(int minor) => MoneyFormat.format(minor);
String _pct(double ratio) => MoneyFormat.percent(ratio);
String _cat(String id) => Categories.byId(id).name;
String _merchant(String key) => TextTools.titleCase(key);

/// Compara el gasto acumulado a la misma altura del mes anterior.
class MonthComparisonRule extends InsightRule {
  const MonthComparisonRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    if (ctx.dayOfMonth < 3) return const [];
    final prevMonth = Dates.addMonths(ctx.monthStart, -1);
    final prevToDate = ctx
        .expensesInMonth(prevMonth)
        .where((t) => t.occurredAt.day <= ctx.dayOfMonth);
    final prev = ctx.sum(prevToDate);
    final cur = ctx.thisMonthSpend;
    if (prev == 0 || cur == 0) return const [];

    final delta = (cur - prev) / prev;
    final prevLabel = Dates.monthNamesEs[prevMonth.month - 1];
    if (delta >= 0.15) {
      return [
        Insight(
          id: 'month_comparison',
          kind: InsightKind.monthComparison,
          severity: InsightSeverity.warning,
          title: 'Vas gastando ${_pct(delta)} más que el mes pasado',
          body:
              'A esta altura de $prevLabel llevabas ${_money(prev)}; hoy llevas ${_money(cur)}. Revisa en qué categoría está la diferencia.',
          amountMinor: cur - prev,
          score: delta * 100,
        ),
      ];
    }
    if (delta <= -0.10) {
      return [
        Insight(
          id: 'month_comparison',
          kind: InsightKind.monthComparison,
          severity: InsightSeverity.positive,
          title: 'Vas ${_pct(-delta)} por debajo del mes pasado',
          body:
              'A esta altura de $prevLabel llevabas ${_money(prev)}; hoy llevas ${_money(cur)}. Buen ritmo.',
          amountMinor: prev - cur,
          score: -delta * 50,
        ),
      ];
    }
    return [
      Insight(
        id: 'month_comparison',
        kind: InsightKind.monthComparison,
        severity: InsightSeverity.info,
        title: 'Vas parejo con el mes pasado',
        body:
            'Llevas ${_money(cur)} frente a ${_money(prev)} a esta altura de $prevLabel.',
        score: 5,
      ),
    ];
  }
}

/// Categoría que creció mucho frente a su promedio de los últimos 3 meses.
class CategorySpikeRule extends InsightRule {
  const CategorySpikeRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final out = <Insight>[];
    final history = <Map<String, int>>[
      for (var i = 1; i <= 3; i++)
        ctx.byCategory(ctx.expensesInMonth(Dates.addMonths(ctx.monthStart, -i))),
    ];
    for (final entry in ctx.thisMonthByCategory.entries) {
      final total = entry.value;
      if (total < Thresholds.spikeMin) continue;
      final past = history
          .map((m) => m[entry.key] ?? 0)
          .where((v) => v > 0)
          .toList();
      if (past.isEmpty) continue;
      final avg = past.reduce((a, b) => a + b) / past.length;
      if (total < avg * 1.4) continue;
      final growth = (total - avg) / avg;
      out.add(Insight(
        id: 'spike_${entry.key}',
        kind: InsightKind.categorySpike,
        severity: InsightSeverity.warning,
        title: 'Tu gasto en ${_cat(entry.key)} se disparó',
        body:
            'Llevas ${_money(total)} este mes, ${_pct(growth)} más que tu promedio de ${_money(avg.round())}.',
        amountMinor: total - avg.round(),
        categoryId: entry.key,
        score: growth * 60,
      ));
    }
    return out;
  }
}

/// Cobros recurrentes (mismo comercio, monto parecido, cada ~30 días).
class SubscriptionsRule extends InsightRule {
  const SubscriptionsRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final recent = ctx.expensesSince(const Duration(days: 120)).where((t) =>
        t.kind == TransactionKind.purchase ||
        t.kind == TransactionKind.billPayment);
    final groups = ctx.byMerchant(recent);
    final subs = <({String merchant, int amount})>[];
    final doubleCharged = <String>[];

    for (final entry in groups.entries) {
      final txs = entry.value..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      if (txs.length < 2) continue;
      var monthlyGap = false;
      for (var i = 1; i < txs.length; i++) {
        final gap = txs[i].occurredAt.difference(txs[i - 1].occurredAt).inDays;
        final a = txs[i].amountMinor;
        final b = txs[i - 1].amountMinor;
        final similar = (a - b).abs() <= (b * 0.10).round() + Thresholds.cop;
        if (gap >= 25 && gap <= 35 && similar) monthlyGap = true;
      }
      if (!monthlyGap) continue;
      subs.add((merchant: entry.key, amount: txs.last.amountMinor));
      final inThisMonth = txs
          .where((t) => Dates.sameMonth(t.occurredAt, ctx.now))
          .length;
      if (inThisMonth >= 2) doubleCharged.add(entry.key);
    }

    if (subs.isEmpty) return const [];
    subs.sort((a, b) => b.amount.compareTo(a.amount));
    final total = subs.fold(0, (acc, s) => acc + s.amount);
    final names = subs.take(4).map((s) => _merchant(s.merchant)).join(', ');
    final more = subs.length > 4 ? ' y ${subs.length - 4} más' : '';

    return [
      Insight(
        id: 'subscriptions',
        kind: InsightKind.subscriptions,
        severity: InsightSeverity.info,
        title:
            '${subs.length} ${subs.length == 1 ? 'cobro recurrente' : 'cobros recurrentes'}: ~${_money(total)} al mes',
        body:
            '$names$more. Revisa cuáles sigues usando; cancelar uno que no usas es el ahorro más fácil.',
        amountMinor: total,
        categoryId: Categories.suscripciones.id,
        score: total / (10000 * Thresholds.cop),
      ),
      for (final m in doubleCharged)
        Insight(
          id: 'double_sub_$m',
          kind: InsightKind.subscriptions,
          severity: InsightSeverity.warning,
          title: '${_merchant(m)} te cobró más de una vez este mes',
          body:
              'Suele ser un cobro mensual. Verifica si fue un cambio de plan o un cobro repetido.',
          score: 40,
        ),
    ];
  }
}

/// Muchas compras pequeñas que suman.
class AntExpensesRule extends InsightRule {
  const AntExpensesRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final small = ctx.thisMonthExpenses
        .where((t) => t.amountMinor <= Thresholds.antExpenseMax)
        .toList();
    if (small.length < 8 || ctx.thisMonthSpend == 0) return const [];
    final total = ctx.sum(small);
    final share = total / ctx.thisMonthSpend;
    if (share < 0.05) return const [];
    return [
      Insight(
        id: 'ant_expenses',
        kind: InsightKind.antExpenses,
        severity: share >= 0.15 ? InsightSeverity.warning : InsightSeverity.info,
        title: 'Gastos hormiga: ${small.length} compras pequeñas suman ${_money(total)}',
        body:
            'Son el ${_pct(share)} de tu gasto del mes. Cafés, domicilios y antojos de menos de ${_money(Thresholds.antExpenseMax)} pesan más de lo que parece.',
        amountMinor: total,
        score: share * 100,
      ),
    ];
  }
}

/// Presupuestos por categoría: superado, cerca del límite o proyección.
class BudgetRule extends InsightRule {
  const BudgetRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final out = <Insight>[];
    for (final entry in ctx.budgets.entries) {
      final limit = entry.value;
      if (limit <= 0) continue;
      final spent = ctx.thisMonthByCategory[entry.key] ?? 0;
      final ratio = spent / limit;
      final name = _cat(entry.key);
      if (ratio >= 1) {
        out.add(Insight(
          id: 'budget_${entry.key}',
          kind: InsightKind.budget,
          severity: InsightSeverity.warning,
          title: 'Superaste tu presupuesto de $name',
          body:
              'Llevas ${_money(spent)} de ${_money(limit)} (${_pct(ratio)}). Lo que gastes de aquí a fin de mes en $name ya va por encima de lo planeado.',
          amountMinor: spent - limit,
          categoryId: entry.key,
          score: 90 + ratio * 10,
        ));
      } else if (ratio >= 0.8) {
        out.add(Insight(
          id: 'budget_${entry.key}',
          kind: InsightKind.budget,
          severity: InsightSeverity.warning,
          title: 'Vas en el ${_pct(ratio)} de tu presupuesto de $name',
          body:
              'Te quedan ${_money(limit - spent)} para ${ctx.daysInMonth - ctx.dayOfMonth} días.',
          amountMinor: limit - spent,
          categoryId: entry.key,
          score: 70,
        ));
      } else if (ctx.dayOfMonth >= 5) {
        final projected = (spent / ctx.dayOfMonth * ctx.daysInMonth).round();
        if (projected > limit) {
          out.add(Insight(
            id: 'budget_${entry.key}',
            kind: InsightKind.budget,
            severity: InsightSeverity.info,
            title: 'A este ritmo superarás tu presupuesto de $name',
            body:
                'Proyección a fin de mes: ${_money(projected)} frente a un límite de ${_money(limit)}.',
            amountMinor: projected - limit,
            categoryId: entry.key,
            score: 50,
          ));
        }
      }
    }
    return out;
  }
}

/// Frecuencia de restaurantes y domicilios.
class DeliveryRule extends InsightRule {
  const DeliveryRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final food = ctx.thisMonthExpenses
        .where((t) => t.categoryId == Categories.restaurantes.id)
        .toList();
    if (food.length < 8) return const [];
    final total = ctx.sum(food);
    final avg = (total / food.length).round();
    return [
      Insight(
        id: 'delivery',
        kind: InsightKind.delivery,
        severity: InsightSeverity.info,
        title: '${food.length} pedidos o salidas a comer este mes',
        body:
            'Suman ${_money(total)}, unos ${_money(avg)} por vez. Reemplazar dos a la semana por comida en casa te ahorraría cerca de ${_money(avg * 8)} al mes.',
        amountMinor: total,
        categoryId: Categories.restaurantes.id,
        score: food.length * 3,
      ),
    ];
  }
}

/// Concentración del gasto en fin de semana.
class WeekendRule extends InsightRule {
  const WeekendRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    if (ctx.thisMonthSpend < Thresholds.weekendMin) return const [];
    final weekend =
        ctx.sum(ctx.thisMonthExpenses.where((t) => Dates.isWeekend(t.occurredAt)));
    final share = weekend / ctx.thisMonthSpend;
    if (share < 0.45) return const [];
    return [
      Insight(
        id: 'weekend',
        kind: InsightKind.weekend,
        severity: InsightSeverity.info,
        title: 'El ${_pct(share)} de tu gasto es en fin de semana',
        body:
            '${_money(weekend)} entre sábados y domingos. Ponerte un tope de fin de semana suele ser más efectivo que recortar entre semana.',
        amountMinor: weekend,
        score: share * 40,
      ),
    ];
  }
}

/// Dos cargos iguales en el mismo comercio con minutos de diferencia.
class DuplicateChargeRule extends InsightRule {
  const DuplicateChargeRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final out = <Insight>[];
    final groups = ctx.byMerchant(ctx.thisMonthExpenses);
    for (final entry in groups.entries) {
      final txs = entry.value..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      for (var i = 1; i < txs.length; i++) {
        final a = txs[i - 1];
        final b = txs[i];
        final close =
            b.occurredAt.difference(a.occurredAt) <= const Duration(minutes: 10);
        if (close && a.amountMinor == b.amountMinor) {
          out.add(Insight(
            id: 'dup_${b.id}',
            kind: InsightKind.duplicateCharge,
            severity: InsightSeverity.warning,
            title: 'Posible cobro doble en ${_merchant(entry.key)}',
            body:
                'Dos cargos de ${_money(a.amountMinor)} el ${Dates.dayLabel(a.occurredAt, now: ctx.now)} con pocos minutos de diferencia. Si no fueron dos compras, reclama al banco.',
            amountMinor: b.amountMinor,
            score: 80,
          ));
        }
      }
    }
    return out;
  }
}

/// Un solo comercio concentra buena parte del gasto.
class TopMerchantRule extends InsightRule {
  const TopMerchantRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    if (ctx.thisMonthSpend == 0) return const [];
    final groups = ctx.byMerchant(ctx.thisMonthExpenses);
    if (groups.isEmpty) return const [];
    MapEntry<String, List<Transaction>>? top;
    var topTotal = 0;
    for (final e in groups.entries) {
      final total = ctx.sum(e.value);
      if (total > topTotal) {
        topTotal = total;
        top = e;
      }
    }
    if (top == null || top.value.length < 3) return const [];
    final share = topTotal / ctx.thisMonthSpend;
    if (share < 0.25) return const [];
    return [
      Insight(
        id: 'top_merchant',
        kind: InsightKind.topMerchant,
        severity: InsightSeverity.info,
        title: '${_merchant(top.key)} se lleva el ${_pct(share)} de tu gasto',
        body:
            '${top.value.length} movimientos por ${_money(topTotal)} este mes.',
        amountMinor: topTotal,
        categoryId: top.value.first.categoryId,
        score: share * 30,
      ),
    ];
  }
}

/// Proyección de cierre de mes al ritmo actual.
class ProjectionRule extends InsightRule {
  const ProjectionRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    if (ctx.dayOfMonth < 5 || ctx.thisMonthSpend == 0) return const [];
    final projected =
        (ctx.thisMonthSpend / ctx.dayOfMonth * ctx.daysInMonth).round();
    final prevTotal =
        ctx.sum(ctx.expensesInMonth(Dates.addMonths(ctx.monthStart, -1)));
    final comparison = prevTotal > 0
        ? ' frente a ${_money(prevTotal)} del mes pasado'
        : '';
    final worse = prevTotal > 0 && projected > prevTotal * 1.2;
    return [
      Insight(
        id: 'projection',
        kind: InsightKind.projection,
        severity: worse ? InsightSeverity.warning : InsightSeverity.info,
        title: 'Cerrarías el mes en ~${_money(projected)}',
        body:
            'Llevas ${_money(ctx.thisMonthSpend)} en ${ctx.dayOfMonth} días$comparison.',
        amountMinor: projected,
        score: worse ? 45 : 10,
      ),
    ];
  }
}

/// Tasa de ahorro cuando se detectan ingresos.
class SavingsRule extends InsightRule {
  const SavingsRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final income = ctx.effectiveIncome;
    if (income == 0) return const [];
    final label = ctx.incomeIsEstimated ? 'Ingreso estimado' : 'Ingresos';
    final rate = (income - ctx.thisMonthSpend) / income;
    if (rate >= 0.2) {
      return [
        Insight(
          id: 'savings',
          kind: InsightKind.savings,
          severity: InsightSeverity.positive,
          title: 'Estás ahorrando el ${_pct(rate)} de tus ingresos',
          body:
              '$label ${_money(income)}, gastos ${_money(ctx.thisMonthSpend)}. Mantener 20% o más es una meta sólida.',
          amountMinor: income - ctx.thisMonthSpend,
          score: 30,
        ),
      ];
    }
    if (rate < 0) {
      return [
        Insight(
          id: 'savings',
          kind: InsightKind.savings,
          severity: InsightSeverity.warning,
          title: 'Este mes gastas más de lo que ingresa',
          body:
              'Gastos ${_money(ctx.thisMonthSpend)} frente a ${label.toLowerCase()} ${_money(income)}. Si es un mes atípico está bien; si se repite, toca ajustar.',
          amountMinor: ctx.thisMonthSpend - income,
          score: 85,
        ),
      ];
    }
    return [
      Insight(
        id: 'savings',
        kind: InsightKind.savings,
        severity: InsightSeverity.info,
        title: 'Ahorras el ${_pct(rate)} de tus ingresos',
        body:
            'La referencia habitual es 20%. Te faltan ${_money((income * 0.2 - (income - ctx.thisMonthSpend)).round())} para llegar.',
        score: 20,
      ),
    ];
  }
}

/// Gastos entre 10 p. m. y 4 a. m.
class NightSpendingRule extends InsightRule {
  const NightSpendingRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    final night = ctx.thisMonthExpenses
        .where((t) => t.occurredAt.hour >= 22 || t.occurredAt.hour < 4)
        .toList();
    if (night.length < 4) return const [];
    return [
      Insight(
        id: 'night',
        kind: InsightKind.nightSpending,
        severity: InsightSeverity.info,
        title: '${night.length} gastos nocturnos este mes',
        body:
            'Suman ${_money(ctx.sum(night))} después de las 10 p. m. Las compras tarde en la noche suelen ser las menos planeadas.',
        amountMinor: ctx.sum(night),
        score: night.length * 2,
      ),
    ];
  }
}

/// Sin datos todavía.
class GettingStartedRule extends InsightRule {
  const GettingStartedRule();

  @override
  List<Insight> evaluate(InsightContext ctx) {
    if (ctx.all.isNotEmpty) return const [];
    return const [
      Insight(
        id: 'getting_started',
        kind: InsightKind.gettingStarted,
        severity: InsightSeverity.info,
        title: 'Aún no hay movimientos',
        body:
            'Activa el acceso a notificaciones en Ajustes y la próxima compra aparecerá sola. También puedes probar con "Simular notificación".',
        score: 1,
      ),
    ];
  }
}

/// Recordatorio de respaldo: los datos solo viven en el teléfono.
class BackupReminderRule extends InsightRule {
  const BackupReminderRule();

  static const int minTransactions = 15;
  static const Duration maxAge = Duration(days: 30);

  @override
  List<Insight> evaluate(InsightContext ctx) {
    if (ctx.all.length < minTransactions) return const [];
    final last = ctx.lastBackupAt;
    if (last != null && ctx.now.difference(last) < maxAge) return const [];
    final days = last == null ? null : ctx.now.difference(last).inDays;
    return [
      Insight(
        id: 'backup',
        kind: InsightKind.backup,
        severity: InsightSeverity.info,
        title: last == null
            ? 'Aún no tienes un respaldo'
            : 'Tu último respaldo fue hace $days días',
        body:
            'Tus ${ctx.all.length} movimientos solo están en este teléfono. Crea un respaldo en Ajustes → Respaldo y exportación y guárdalo en Drive o en tu computador.',
        score: last == null ? 25 : 15,
      ),
    ];
  }
}
