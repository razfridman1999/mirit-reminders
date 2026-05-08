import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mirit_reminders/core/constants/app_colors.dart';
import 'package:mirit_reminders/core/database/tables/reminders_table.dart';
import 'package:mirit_reminders/features/reminders/domain/entities/reminder.dart';
import 'package:mirit_reminders/features/reminders/presentation/providers/reminders_provider.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  // Default to the 7-day period — matches the smallest segment label.
  int _periodDays = 7;

  /// Count consecutive days (ending today or yesterday) where at least one
  /// reminder was marked completed. If today has no completions yet, we look
  /// back from yesterday so an active streak isn't broken before the day ends.
  int _computeStreak(List<Reminder> reminders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final completionDays = reminders
        .where((r) => r.completedAt != null)
        .map((r) => DateTime(
            r.completedAt!.year, r.completedAt!.month, r.completedAt!.day))
        .toSet();

    var day = completionDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));

    var streak = 0;
    while (completionDays.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(allRemindersProvider);
    final reminders = remindersAsync.valueOrNull ?? const <Reminder>[];

    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: _periodDays));
    final streak = _computeStreak(reminders);

    final completed = reminders
        .where((r) =>
            r.completedAt != null && r.completedAt!.isAfter(cutoff))
        .toList();

    final missed = reminders
        .where((r) =>
            r.recurrenceType == RecurrenceType.none &&
            r.completedAt == null &&
            r.isActive &&
            r.scheduledAt.isBefore(now) &&
            r.scheduledAt.isAfter(cutoff))
        .toList();

    final upcoming = reminders.where((r) {
      if (!r.isActive) return false;
      if (r.recurrenceType == RecurrenceType.none) {
        return r.scheduledAt.isAfter(now) && r.completedAt == null;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('סטטיסטיקות'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StreakCard(streak: streak),
            const SizedBox(height: 16),
            _PeriodSelector(
              value: _periodDays,
              onChanged: (v) => setState(() => _periodDays = v),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _MetricCard(
                  label: 'בוצעו',
                  count: completed.length,
                  icon: Icons.check_circle,
                  color: AppColors.primary,
                ),
                _MetricCard(
                  label: 'פוספסו',
                  count: missed.length,
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                ),
                _MetricCard(
                  label: 'עתידיות',
                  count: upcoming.length,
                  icon: Icons.schedule,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (completed.isEmpty)
              const _EmptyState()
            else
              _BarChart(
                completedAt: completed
                    .map((r) => r.completedAt!)
                    .toList(growable: false),
                periodDays: _periodDays,
                now: now,
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('7 ימים')),
        ButtonSegment(value: 30, label: Text('30 ימים')),
        ButtonSegment(value: 365, label: Text('שנה')),
      ],
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // Three across when there's enough room; otherwise two-up / one-up.
    final available = width - 32; // outer padding
    final cardWidth = available >= 600
        ? (available - 24) / 3
        : available >= 360
            ? (available - 12) / 2
            : available;

    return SizedBox(
      width: cardWidth,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 96,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'עוד לא בוצעו תזכורות בתקופה זו',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'סמני תזכורות שביצעת ויופיעו כאן',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStreak = streak > 0;
    final emoji = streak >= 30
        ? '🔥🔥🔥'
        : streak >= 7
            ? '🔥🔥'
            : streak >= 1
                ? '🔥'
                : '💤';
    final label = streak == 1
        ? 'יום רצוף'
        : streak == 0
            ? 'אין רצף כרגע'
            : '$streak ימים רצופים';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: hasStreak
          ? AppColors.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'רצף ביצוע',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasStreak
                          ? AppColors.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (hasStreak)
              Text(
                '$streak',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Buckets completion timestamps into per-day (or per-week for the 365 period)
/// counts and renders them with [CustomPaint].
class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.completedAt,
    required this.periodDays,
    required this.now,
  });

  final List<DateTime> completedAt;
  final int periodDays;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = _buildBuckets();

    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: _BarChartPainter(
          buckets: buckets,
          barColor: AppColors.primary,
          labelColor: theme.colorScheme.onSurfaceVariant,
          valueColor: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  List<_Bucket> _buildBuckets() {
    // 365 days compresses to ~52 weekly buckets to keep bars readable;
    // 7 and 30 stay as one-bar-per-day.
    if (periodDays >= 365) {
      return _weeklyBuckets();
    }
    return _dailyBuckets();
  }

  List<_Bucket> _dailyBuckets() {
    final today = DateTime(now.year, now.month, now.day);
    final list = <_Bucket>[];
    for (var i = periodDays - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      list.add(_Bucket(label: '${day.day}', count: 0, date: day));
    }
    for (final ts in completedAt) {
      final d = DateTime(ts.year, ts.month, ts.day);
      final daysAgo = today.difference(d).inDays;
      if (daysAgo < 0 || daysAgo >= periodDays) continue;
      final idx = periodDays - 1 - daysAgo;
      list[idx] = list[idx].copyAddOne();
    }
    return list;
  }

  List<_Bucket> _weeklyBuckets() {
    // ~52 weeks ending today; label by ISO-ish week-of-year.
    final today = DateTime(now.year, now.month, now.day);
    const weeks = 52;
    final list = <_Bucket>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final weekStart = today.subtract(Duration(days: i * 7));
      list.add(
        _Bucket(label: '${_weekOfYear(weekStart)}', count: 0, date: weekStart),
      );
    }
    for (final ts in completedAt) {
      final d = DateTime(ts.year, ts.month, ts.day);
      final daysAgo = today.difference(d).inDays;
      if (daysAgo < 0 || daysAgo >= weeks * 7) continue;
      final weeksAgo = daysAgo ~/ 7;
      final idx = weeks - 1 - weeksAgo;
      list[idx] = list[idx].copyAddOne();
    }
    return list;
  }

  static int _weekOfYear(DateTime date) {
    final firstDay = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDay).inDays;
    return ((daysDiff + firstDay.weekday) / 7).ceil();
  }
}

class _Bucket {
  const _Bucket({required this.label, required this.count, required this.date});
  final String label;
  final int count;
  final DateTime date;

  _Bucket copyAddOne() =>
      _Bucket(label: label, count: count + 1, date: date);
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.buckets,
    required this.barColor,
    required this.labelColor,
    required this.valueColor,
  });

  final List<_Bucket> buckets;
  final Color barColor;
  final Color labelColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;

    const labelHeight = 16.0;
    const valueHeight = 14.0;
    final chartHeight = size.height - labelHeight - valueHeight - 4;
    if (chartHeight <= 0) return;

    final maxCount =
        buckets.fold<int>(0, (m, b) => b.count > m ? b.count : m);
    if (maxCount == 0) return;

    final n = buckets.length;
    final slotWidth = size.width / n;
    final barWidth = (slotWidth * 0.6).clamp(1.0, 24.0);

    final barPaint = Paint()..color = barColor;

    // Drop labels when buckets are too dense to keep them legible.
    final showLabel = slotWidth >= 18;
    final labelStride = showLabel
        ? 1
        : (n / (size.width / 24)).ceil().clamp(1, n);

    for (var i = 0; i < n; i++) {
      final b = buckets[i];
      final centerX = slotWidth * (i + 0.5);
      final barH = (b.count / maxCount) * chartHeight;
      final top = valueHeight + 4 + (chartHeight - barH);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - barWidth / 2, top, barWidth, barH),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);

      if (b.count > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${b.count}',
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        if (tp.width <= slotWidth) {
          tp.paint(
            canvas,
            Offset(centerX - tp.width / 2, top - tp.height - 2),
          );
        }
      }

      if (showLabel || i % labelStride == 0) {
        final lp = TextPainter(
          text: TextSpan(
            text: b.label,
            style: TextStyle(color: labelColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '',
        )..layout(maxWidth: slotWidth);
        lp.paint(
          canvas,
          Offset(centerX - lp.width / 2, size.height - lp.height),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) {
    if (old.buckets.length != buckets.length) return true;
    if (old.barColor != barColor ||
        old.labelColor != labelColor ||
        old.valueColor != valueColor) {
      return true;
    }
    for (var i = 0; i < buckets.length; i++) {
      if (old.buckets[i].count != buckets[i].count ||
          old.buckets[i].label != buckets[i].label) {
        return true;
      }
    }
    return false;
  }
}
