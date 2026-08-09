import '../../../imports.dart';
import '../db/document_parser.dart';

/// The spreadsheet reader.
///
/// A spreadsheet is the one preview where the app's usual layout instincts are
/// wrong. Everything else here is a reading column; this needs a grid that
/// scrolls both ways with a header row and a header column that stay put,
/// because a cell in the middle of a wide sheet is meaningless once its labels
/// have scrolled off.
///
/// It draws its own grid rather than using `DataTable`, which brings Material's
/// dividers, its own row heights, and a sort affordance this has no use for.
class SheetView extends StatefulWidget {
  const SheetView({super.key, required this.document});

  final SpreadsheetDoc document;

  @override
  State<SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends State<SheetView> {
  final ScrollController _horizontal = ScrollController();
  int _sheet = 0;

  static const double _rowHeight = 38;
  static const double _cellWidth = 148;
  static const double _gutterWidth = 52;

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final sheets = widget.document.sheets;

    if (widget.document.isEmpty) {
      return LdEmptyState(
        title: l10n.sheetEmptyTitle,
        message: l10n.sheetEmptyBody,
        glyph: LdGlyph.grid,
        tint: LdColors.fileSpreadsheet,
      );
    }

    final sheet = sheets[_sheet.clamp(0, sheets.length - 1)];
    final columns = sheet.columnCount;

    return Column(
      children: <Widget>[
        Expanded(
          child: Scrollbar(
            controller: _horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _gutterWidth + columns * _cellWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // the column letters, which stay while the rows scroll
                    _HeaderRow(
                      columns: columns,
                      cellWidth: _cellWidth,
                      gutterWidth: _gutterWidth,
                      height: _rowHeight,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sheet.rows.length,
                        itemExtent: _rowHeight,
                        itemBuilder: (context, index) => _Row(
                          number: index + 1,
                          cells: sheet.rows[index],
                          cellWidth: _cellWidth,
                          gutterWidth: _gutterWidth,
                          // the first row of real data reads as headings in
                          // almost every sheet anyone actually opens
                          emphasised: index == 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // the sheet tabs, only when there is more than one to choose from
        if (sheets.length > 1)
          _SheetTabs(
            sheets: sheets,
            selected: _sheet,
            onSelected: (index) => setState(() => _sheet = index),
          ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.cellWidth,
    required this.gutterWidth,
    required this.height,
  });

  final int columns;
  final double cellWidth;
  final double gutterWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(
          color: LdColors.foregroundSecondary,
        );

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: LdColors.backgroundElevated,
        border: Border(bottom: BorderSide(color: LdColors.strokeOutline)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: gutterWidth),
          for (var i = 0; i < columns; i++)
            Container(
              width: cellWidth,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: LdColors.strokeOutline),
                ),
              ),
              child: Text(columnLabel(i), style: style),
            ),
        ],
      ),
    );
  }

  /// 0 is A, 25 is Z, 26 is AA. Base 26 with no zero, the same scheme the
  /// file's own cell references use.
  static String columnLabel(int index) {
    var n = index;
    final buffer = StringBuffer();
    while (true) {
      buffer.write(String.fromCharCode(65 + n % 26));
      n = n ~/ 26 - 1;
      if (n < 0) break;
    }
    return String.fromCharCodes(buffer.toString().codeUnits.reversed);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.number,
    required this.cells,
    required this.cellWidth,
    required this.gutterWidth,
    required this.emphasised,
  });

  final int number;
  final List<String> cells;
  final double cellWidth;
  final double gutterWidth;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = emphasised
        ? theme.labelMedium!.copyWith(color: LdColors.foregroundPrimary)
        : theme.bodySmall!.copyWith(color: LdColors.foregroundPrimary);

    return DecoratedBox(
      decoration: BoxDecoration(
        // banded rows, faintly, which makes a wide sheet trackable
        color: number.isEven
            ? LdColors.backgroundElevated.withValues(alpha: 0.35)
            : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: LdColors.strokeOutline, width: 0.5),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: gutterWidth,
            child: Text(
              LdFormat.count(context, number),
              textAlign: TextAlign.center,
              style: theme.labelSmall!.copyWith(
                color: LdColors.foregroundMuted,
              ),
            ),
          ),
          for (final cell in cells)
            Container(
              width: cellWidth,
              alignment: _isNumeric(cell)
                  // numbers right align, which is the only way a column of
                  // them can be compared at a glance
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: LdColors.strokeOutline)),
              ),
              child: Text(
                cell,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
        ],
      ),
    );
  }

  static bool _isNumeric(String value) {
    if (value.isEmpty) return false;
    return double.tryParse(value.replaceAll(',', '')) != null;
  }
}

class _SheetTabs extends StatelessWidget {
  const _SheetTabs({
    required this.sheets,
    required this.selected,
    required this.onSelected,
  });

  final List<Sheet> sheets;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: LdColors.backgroundSunken,
        border: Border(top: BorderSide(color: LdColors.strokeOutline)),
      ),
      child: SafeArea(
        top: false,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: sheets.length,
          itemBuilder: (context, index) {
            final active = index == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LdTappable(
                onTap: () => onSelected(index),
                borderRadius: LdRadii.pillRadius,
                child: AnimatedContainer(
                  duration: LdMotion.tapFade,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? LdColors.fileSpreadsheet.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: LdRadii.pillRadius,
                    border: Border.all(
                      color: active
                          ? LdColors.fileSpreadsheet
                          : LdColors.strokeOutline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      sheets[index].name.isEmpty
                          ? L10n.of(context).sheetUnnamed(
                              LdFormat.count(context, index + 1),
                            )
                          : sheets[index].name,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: active
                                ? LdColors.foregroundPrimary
                                : LdColors.foregroundSecondary,
                          ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
