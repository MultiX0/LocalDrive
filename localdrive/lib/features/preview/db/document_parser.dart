import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads the office formats well enough to show them.
///
/// xlsx, docx, ods and odt are all a zip of XML, so one set of machinery
/// covers all four instead of pulling in a packaged viewer per format, and
/// the rendered result stays consistent with the rest of the app.
///
/// A reader, not an editor: resolves values, not formulas, and formatting
/// only where it carries meaning.
abstract final class DocumentParser {
  /// A spreadsheet, as sheets of rows of cells.
  static SpreadsheetDoc spreadsheet(Uint8List bytes, String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.csv') || lower.endsWith('.tsv')) {
      return _delimited(bytes, tab: lower.endsWith('.tsv'));
    }
    if (lower.endsWith('.ods')) return _ods(bytes);
    return _xlsx(bytes);
  }

  /// A word processor document, as a flow of paragraphs.
  static TextDoc document(Uint8List bytes, String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.odt')) return _odt(bytes);
    if (lower.endsWith('.rtf')) return _rtf(bytes);
    return _docx(bytes);
  }

  // spreadsheets

  /// CSV, parsed properly rather than by splitting on commas.
  ///
  /// A quoted field can contain the delimiter, a newline, and an escaped
  /// quote, and a naive split gets all three wrong on real exported data.
  static SpreadsheetDoc _delimited(Uint8List bytes, {required bool tab}) {
    final text = _decode(bytes);
    final delimiter = tab ? '\t' : ',';

    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (quoted) {
        if (char != '"') {
          cell.write(char);
          continue;
        }
        // a doubled quote inside a quoted field is one literal quote
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
          continue;
        }
        quoted = false;
        continue;
      }

      switch (char) {
        case '"':
          quoted = true;
        case '\r':
          break;
        case '\n':
          row.add(cell.toString());
          cell.clear();
          rows.add(row);
          row = <String>[];
        default:
          if (char == delimiter) {
            row.add(cell.toString());
            cell.clear();
          } else {
            cell.write(char);
          }
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }

    return SpreadsheetDoc(
      sheets: <Sheet>[Sheet(name: '', rows: _pad(rows))],
    );
  }

  static SpreadsheetDoc _xlsx(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);

    // strings are held once in a shared table and referenced by index, which
    // is why a cell can read `<v>7</v>` and mean a word
    final shared = <String>[];
    final sharedFile = _entry(zip, 'xl/sharedStrings.xml');
    if (sharedFile != null) {
      for (final si in _parse(sharedFile).findAllElements('si')) {
        shared.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    }

    // sheet names live in the workbook, the cells in separate parts
    final names = <String>[];
    final workbook = _entry(zip, 'xl/workbook.xml');
    if (workbook != null) {
      for (final sheet in _parse(workbook).findAllElements('sheet')) {
        names.add(sheet.getAttribute('name') ?? '');
      }
    }

    final sheets = <Sheet>[];
    for (var index = 1;; index++) {
      final part = _entry(zip, 'xl/worksheets/sheet$index.xml');
      if (part == null) break;
      sheets.add(
        Sheet(
          name: index <= names.length ? names[index - 1] : '',
          rows: _xlsxRows(_parse(part), shared),
        ),
      );
    }

    return SpreadsheetDoc(sheets: sheets);
  }

  static List<List<String>> _xlsxRows(XmlDocument doc, List<String> shared) {
    final rows = <List<String>>[];

    for (final row in doc.findAllElements('row')) {
      final cells = <int, String>{};
      var widest = 0;

      for (final cell in row.findElements('c')) {
        // the cell reference is a column letter and a row number. Sparse
        // sheets omit empty cells entirely, so the letter is the only thing
        // that says which column this value actually belongs in
        final column = _columnIndex(cell.getAttribute('r') ?? '');
        final type = cell.getAttribute('t');

        String value;
        if (type == 'inlineStr') {
          value = cell.findAllElements('t').map((t) => t.innerText).join();
        } else {
          final raw = cell.findElements('v').firstOrNull?.innerText ?? '';
          if (type == 's') {
            final index = int.tryParse(raw) ?? -1;
            value = index >= 0 && index < shared.length ? shared[index] : '';
          } else {
            value = raw;
          }
        }

        cells[column] = value;
        if (column + 1 > widest) widest = column + 1;
      }

      rows.add(<String>[
        for (var i = 0; i < widest; i++) cells[i] ?? '',
      ]);
    }
    return _pad(rows);
  }

  /// "BC12" is column 55. Letters are base 26 with no zero, which is why this
  /// is not simply `letter - 'A'`.
  static int _columnIndex(String reference) {
    var index = 0;
    for (final unit in reference.codeUnits) {
      if (unit < 65 || unit > 90) break;
      index = index * 26 + (unit - 64);
    }
    return index > 0 ? index - 1 : 0;
  }

  static SpreadsheetDoc _ods(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final content = _entry(zip, 'content.xml');
    if (content == null) return const SpreadsheetDoc(sheets: <Sheet>[]);

    final doc = _parse(content);
    final sheets = <Sheet>[];

    for (final table in doc.findAllElements('table:table')) {
      final rows = <List<String>>[];
      for (final row in table.findElements('table:table-row')) {
        final cells = <String>[];
        for (final cell in row.findElements('table:table-cell')) {
          // OpenDocument collapses runs of identical cells into one element
          // with a repeat count, which is how a blank row becomes 1024 columns
          final repeat = int.tryParse(
                cell.getAttribute('table:number-columns-repeated') ?? '1',
              ) ??
              1;
          final text = cell
              .findAllElements('text:p')
              .map((p) => p.innerText)
              .join('\n');
          // a repeat in the thousands is padding, not data
          for (var i = 0; i < repeat && i < 256; i++) {
            cells.add(text);
          }
        }
        while (cells.isNotEmpty && cells.last.isEmpty) {
          cells.removeLast();
        }
        rows.add(cells);
      }
      while (rows.isNotEmpty && rows.last.every((c) => c.isEmpty)) {
        rows.removeLast();
      }
      sheets.add(
        Sheet(name: table.getAttribute('table:name') ?? '', rows: _pad(rows)),
      );
    }
    return SpreadsheetDoc(sheets: sheets);
  }

  // documents

  static TextDoc _docx(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final part = _entry(zip, 'word/document.xml');
    if (part == null) return const TextDoc(blocks: <DocBlock>[]);

    final doc = _parse(part);
    final blocks = <DocBlock>[];

    for (final p in doc.findAllElements('w:p')) {
      final styleId = p
              .findElements('w:pPr')
              .firstOrNull
              ?.findElements('w:pStyle')
              .firstOrNull
              ?.getAttribute('w:val') ??
          '';
      final numbered = p
              .findElements('w:pPr')
              .firstOrNull
              ?.findElements('w:numPr')
              .firstOrNull !=
          null;

      final spans = <DocSpan>[];
      for (final run in p.findAllElements('w:r')) {
        final text = run.findElements('w:t').map((t) => t.innerText).join();
        if (text.isEmpty) continue;
        final props = run.findElements('w:rPr').firstOrNull;
        spans.add(
          DocSpan(
            text: text,
            bold: props?.findElements('w:b').isNotEmpty ?? false,
            italic: props?.findElements('w:i').isNotEmpty ?? false,
            underline: props?.findElements('w:u').isNotEmpty ?? false,
          ),
        );
      }

      blocks.add(
        DocBlock(
          spans: spans,
          // Heading1 through Heading6, however the producer capitalised it
          headingLevel: _headingLevel(styleId),
          bullet: numbered || styleId.toLowerCase().contains('listparagraph'),
        ),
      );
    }
    return TextDoc(blocks: blocks);
  }

  static TextDoc _odt(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final content = _entry(zip, 'content.xml');
    if (content == null) return const TextDoc(blocks: <DocBlock>[]);

    final doc = _parse(content);
    final blocks = <DocBlock>[];

    for (final node in doc.findAllElements('office:text')) {
      for (final child in node.childElements) {
        final name = child.name.qualified;
        if (name == 'text:h') {
          blocks.add(
            DocBlock(
              spans: <DocSpan>[DocSpan(text: child.innerText)],
              headingLevel:
                  int.tryParse(child.getAttribute('text:outline-level') ?? '1') ??
                      1,
            ),
          );
        } else if (name == 'text:p') {
          blocks.add(
            DocBlock(spans: <DocSpan>[DocSpan(text: child.innerText)]),
          );
        } else if (name == 'text:list') {
          for (final item in child.findAllElements('text:p')) {
            blocks.add(
              DocBlock(
                spans: <DocSpan>[DocSpan(text: item.innerText)],
                bullet: true,
              ),
            );
          }
        }
      }
    }
    return TextDoc(blocks: blocks);
  }

  /// RTF, reduced to its text.
  ///
  /// RTF is a control-word format rather than XML, and rendering it properly
  /// would be a project of its own. Stripping to readable text is honest about
  /// what this is: enough to read the document, not enough to typeset it.
  static TextDoc _rtf(Uint8List bytes) {
    final raw = _decode(bytes);
    final buffer = StringBuffer();
    var depth = 0;
    var skipping = false;

    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == '{') {
        depth++;
        continue;
      }
      if (char == '}') {
        depth--;
        skipping = false;
        continue;
      }
      if (char == r'\') {
        final word = StringBuffer();
        var j = i + 1;
        while (j < raw.length && RegExp(r'[a-zA-Z]').hasMatch(raw[j])) {
          word.write(raw[j]);
          j++;
        }
        final control = word.toString();
        // these groups are metadata, not the document's own words
        if (<String>{'fonttbl', 'colortbl', 'stylesheet', 'info', 'pict'}
            .contains(control)) {
          skipping = true;
        }
        if (control == 'par' || control == 'line') buffer.write('\n');
        i = j - 1;
        continue;
      }
      if (!skipping && depth > 0) buffer.write(char);
    }

    return TextDoc(
      blocks: <DocBlock>[
        for (final line in buffer.toString().split('\n'))
          DocBlock(spans: <DocSpan>[DocSpan(text: line.trim())]),
      ],
    );
  }

  // shared

  static int _headingLevel(String styleId) {
    final match = RegExp(r'heading\s*([1-6])', caseSensitive: false)
        .firstMatch(styleId.replaceAll(' ', ''));
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  static ArchiveFile? _entry(Archive zip, String path) {
    for (final file in zip.files) {
      if (file.name == path && file.isFile) return file;
    }
    return null;
  }

  static XmlDocument _parse(ArchiveFile file) =>
      XmlDocument.parse(_decode(file.content));

  /// Office files are UTF-8 in practice, but a CSV exported from a spreadsheet
  /// on Windows may not be. A malformed byte becomes a replacement character
  /// rather than an exception, because half a readable file beats none.
  static String _decode(Uint8List bytes) {
    // strip a byte order mark, which otherwise shows as a stray glyph in the
    // very first cell of every file Excel exported
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }
    return utf8.decode(data, allowMalformed: true);
  }

  /// Every row the same width, so the table has straight columns even when the
  /// source omitted trailing empty cells.
  static List<List<String>> _pad(List<List<String>> rows) {
    var widest = 0;
    for (final row in rows) {
      if (row.length > widest) widest = row.length;
    }
    return <List<String>>[
      for (final row in rows)
        <String>[
          ...row,
          for (var i = row.length; i < widest; i++) '',
        ],
    ];
  }
}

/// A spreadsheet, as plain values. No formulas, no styling: this is a reader.
class SpreadsheetDoc {
  const SpreadsheetDoc({required this.sheets});

  final List<Sheet> sheets;

  bool get isEmpty => sheets.every((sheet) => sheet.rows.isEmpty);
}

class Sheet {
  const Sheet({required this.name, required this.rows});

  final String name;
  final List<List<String>> rows;

  int get columnCount => rows.isEmpty ? 0 : rows.first.length;
}

/// A document, as a flow of paragraphs.
class TextDoc {
  const TextDoc({required this.blocks});

  final List<DocBlock> blocks;

  bool get isEmpty => blocks.every((block) => block.text.trim().isEmpty);
}

class DocBlock {
  const DocBlock({
    required this.spans,
    this.headingLevel = 0,
    this.bullet = false,
  });

  final List<DocSpan> spans;

  /// 1 to 6, or 0 for body text
  final int headingLevel;
  final bool bullet;

  String get text => spans.map((span) => span.text).join();
  bool get isHeading => headingLevel > 0;
}

class DocSpan {
  const DocSpan({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
}
