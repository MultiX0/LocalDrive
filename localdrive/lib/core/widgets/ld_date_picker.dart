import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_radii.dart';
import 'ld_bottom_sheet.dart';
import 'ld_button.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// A branded date and time picker, replacing showDatePicker. Used for share
/// link expiry and anywhere else a specific moment is needed.
abstract final class LdDatePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required String cancelLabel,
    DateTime? initial,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final now = DateTime.now();
    return LdBottomSheet.show<DateTime>(
      context,
      title: title,
      scrollable: false,
      builder: (context) => _CalendarBody(
        initial: initial ?? now.add(const Duration(days: 7)),
        firstDate: firstDate ?? now,
        lastDate: lastDate ?? DateTime(now.year + 5),
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
  }
}

class _CalendarBody extends StatefulWidget {
  const _CalendarBody({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  late DateTime _visibleMonth =
      DateTime(widget.initial.year, widget.initial.month);
  late DateTime _selected = widget.initial;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _selectable(DateTime day) =>
      !day.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month,
          widget.firstDate.day)) &&
      !day.isAfter(widget.lastDate);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final monthFormat = DateFormat.yMMMM(locale);
    final weekdayFormat = DateFormat.E(locale);

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final leadingBlanks = firstOfMonth.weekday % 7;
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            LdTappable(
              onTap: () => setState(() {
                _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month - 1);
              }),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: LdIcon(LdGlyph.chevronLeft, size: 20),
              ),
            ),
            Expanded(
              child: Text(
                monthFormat.format(_visibleMonth),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            LdTappable(
              onTap: () => setState(() {
                _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month + 1);
              }),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: LdIcon(LdGlyph.chevronRight, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Text(
                  weekdayFormat.format(DateTime(2024, 1, 7 + i)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = DateTime(
              _visibleMonth.year,
              _visibleMonth.month,
              index - leadingBlanks + 1,
            );
            final selected = _sameDay(day, _selected);
            final enabled = _selectable(day);
            return LdTappable(
              onTap: enabled
                  ? () => setState(() => _selected = DateTime(
                        day.year,
                        day.month,
                        day.day,
                        _selected.hour,
                        _selected.minute,
                      ))
                  : null,
              enabled: enabled,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? LdColors.accentPrimary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: !enabled
                            ? LdColors.foregroundMuted
                            : selected
                                ? LdColors.foregroundPrimary
                                : LdColors.foregroundPrimary,
                      ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _TimeRow(
          value: _selected,
          onChanged: (next) => setState(() => _selected = next),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: LdButton.secondary(
                label: widget.cancelLabel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LdButton(
                label: widget.confirmLabel,
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final format = DateFormat.Hm(locale);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LdColors.backgroundPrimary,
        borderRadius: LdRadii.fieldRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Row(
        children: <Widget>[
          const LdIcon(
            LdGlyph.clock,
            size: 18,
            color: LdColors.foregroundSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              format.format(value),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          _Stepper(
            onUp: () => onChanged(value.add(const Duration(hours: 1))),
            onDown: () => onChanged(value.subtract(const Duration(hours: 1))),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.onUp, required this.onDown});

  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LdTappable(
          onTap: onDown,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: LdIcon(LdGlyph.arrowDown, size: 16),
          ),
        ),
        LdTappable(
          onTap: onUp,
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: LdIcon(LdGlyph.arrowUp, size: 16),
          ),
        ),
      ],
    );
  }
}
