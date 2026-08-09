import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/features/preview/db/document_parser.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// Builds a zip the way the office formats do, so what is being parsed is
/// visible in the test rather than a checked-in binary blob.
Uint8List _zip(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final data = utf8.encode(entry.value);
    archive.addFile(ArchiveFile.bytes(entry.key, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('csv', () {
    test('a quoted field keeps its commas, quotes and newlines', () {
      final doc = DocumentParser.spreadsheet(
        _bytes('name,note\n"Smith, J","he said ""hi"""\n'),
        'people.csv',
      );

      final rows = doc.sheets.single.rows;
      expect(rows[0], <String>['name', 'note']);
      expect(rows[1][0], 'Smith, J');
      expect(rows[1][1], 'he said "hi"');
    });

    test('a byte order mark does not end up in the first cell', () {
      final doc = DocumentParser.spreadsheet(
        Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode('id,name')]),
        'export.csv',
      );
      expect(doc.sheets.single.rows.first.first, 'id');
    });

    test('every row comes back the same width', () {
      final doc = DocumentParser.spreadsheet(
        _bytes('a,b,c\n1\n2,3\n'),
        'ragged.csv',
      );
      final widths = doc.sheets.single.rows.map((row) => row.length).toSet();
      expect(widths, <int>{3});
    });

    test('tabs are honoured for a tsv', () {
      final doc = DocumentParser.spreadsheet(
        _bytes('a\tb\n1\t2\n'),
        'data.tsv',
      );
      expect(doc.sheets.single.rows[1], <String>['1', '2']);
    });
  });

  group('xlsx', () {
    test('shared strings are resolved and sparse columns keep their place', () {
      // C1 with no B1: the cell reference is the only thing that says this
      // value belongs in the third column
      final bytes = _zip(<String, String>{
        'xl/workbook.xml':
            '<workbook><sheets><sheet name="Totals"/></sheets></workbook>',
        'xl/sharedStrings.xml':
            '<sst><si><t>Revenue</t></si><si><t>Cost</t></si></sst>',
        'xl/worksheets/sheet1.xml': '<worksheet><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c>'
            '<c r="C1" t="s"><v>1</v></c></row>'
            '<row r="2"><c r="A2"><v>1200</v></c></row>'
            '</sheetData></worksheet>',
      });

      final doc = DocumentParser.spreadsheet(bytes, 'book.xlsx');
      final sheet = doc.sheets.single;

      expect(sheet.name, 'Totals');
      expect(sheet.rows[0], <String>['Revenue', '', 'Cost']);
      expect(sheet.rows[1][0], '1200');
      // padded, so the table has straight columns
      expect(sheet.rows[1].length, 3);
    });

    test('an inline string is read without the shared table', () {
      final bytes = _zip(<String, String>{
        'xl/worksheets/sheet1.xml': '<worksheet><sheetData>'
            '<row r="1"><c r="A1" t="inlineStr"><is><t>Hello</t></is></c></row>'
            '</sheetData></worksheet>',
      });
      final doc = DocumentParser.spreadsheet(bytes, 'inline.xlsx');
      expect(doc.sheets.single.rows.first.first, 'Hello');
    });

    test('a column past Z lands in the right place', () {
      // AA is the 27th column, so this row is 27 wide with one value at the end
      final bytes = _zip(<String, String>{
        'xl/worksheets/sheet1.xml': '<worksheet><sheetData>'
            '<row r="1"><c r="AA1"><v>9</v></c></row>'
            '</sheetData></worksheet>',
      });
      final row = DocumentParser.spreadsheet(bytes, 'wide.xlsx')
          .sheets
          .single
          .rows
          .first;
      expect(row.length, 27);
      expect(row.last, '9');
    });
  });

  group('ods', () {
    test('a repeated cell is expanded, and padding is not mistaken for data',
        () {
      final bytes = _zip(<String, String>{
        'content.xml': '<office:document-content '
            'xmlns:office="urn:office" xmlns:table="urn:table" '
            'xmlns:text="urn:text">'
            '<office:body><office:spreadsheet>'
            '<table:table table:name="Sheet1">'
            '<table:table-row>'
            '<table:table-cell><text:p>x</text:p></table:table-cell>'
            '<table:table-cell table:number-columns-repeated="3">'
            '<text:p>y</text:p></table:table-cell>'
            '<table:table-cell table:number-columns-repeated="16384"/>'
            '</table:table-row>'
            '</table:table>'
            '</office:spreadsheet></office:body></office:document-content>',
      });

      final sheet = DocumentParser.spreadsheet(bytes, 'book.ods').sheets.single;
      expect(sheet.name, 'Sheet1');
      // x, then y three times. The trailing sixteen thousand empties are
      // padding the format writes, not columns anyone has data in
      expect(sheet.rows.single, <String>['x', 'y', 'y', 'y']);
    });
  });

  group('docx', () {
    test('headings, emphasis and lists survive; the rest is dropped', () {
      final bytes = _zip(<String, String>{
        'word/document.xml': '<w:document xmlns:w="urn:w"><w:body>'
            '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr>'
            '<w:r><w:t>Title</w:t></w:r></w:p>'
            '<w:p><w:r><w:t>plain </w:t></w:r>'
            '<w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r></w:p>'
            '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr>'
            '<w:r><w:t>an item</w:t></w:r></w:p>'
            '</w:body></w:document>',
      });

      final doc = DocumentParser.document(bytes, 'report.docx');
      expect(doc.blocks.length, 3);

      expect(doc.blocks[0].headingLevel, 1);
      expect(doc.blocks[0].text, 'Title');

      expect(doc.blocks[1].spans.length, 2);
      expect(doc.blocks[1].spans[0].bold, isFalse);
      expect(doc.blocks[1].spans[1].bold, isTrue);
      expect(doc.blocks[1].text, 'plain bold');

      expect(doc.blocks[2].bullet, isTrue);
    });
  });

  group('odt', () {
    test('headings keep their level and list items are marked', () {
      final bytes = _zip(<String, String>{
        'content.xml': '<office:document-content '
            'xmlns:office="urn:office" xmlns:text="urn:text">'
            '<office:body><office:text>'
            '<text:h text:outline-level="2">Section</text:h>'
            '<text:p>Body copy.</text:p>'
            '<text:list><text:list-item><text:p>One</text:p></text:list-item>'
            '</text:list>'
            '</office:text></office:body></office:document-content>',
      });

      final doc = DocumentParser.document(bytes, 'notes.odt');
      expect(doc.blocks[0].headingLevel, 2);
      expect(doc.blocks[1].text, 'Body copy.');
      expect(doc.blocks[2].bullet, isTrue);
      expect(doc.blocks[2].text, 'One');
    });
  });

  group('garbage', () {
    test('a file that is not what its name claims comes back empty', () {
      // this runs on whatever anyone uploads. The decoder finds no entries
      // rather than throwing, so the viewer shows its "nothing in it" state.
      // That is the right outcome: from here a corrupt file and an empty one
      // genuinely are indistinguishable, and claiming otherwise would be
      // guessing
      expect(
        DocumentParser.spreadsheet(_bytes('not a zip at all'), 'x.xlsx').isEmpty,
        isTrue,
      );
      expect(
        DocumentParser.document(_bytes('not a zip at all'), 'x.docx').isEmpty,
        isTrue,
      );
    });

    test('a truncated zip does not take the app down', () {
      // a real zip, cut in half. The index lives at the end, so this is the
      // shape a half-finished download actually has
      final whole = _zip(<String, String>{'a.txt': 'hello world'});
      final half = Uint8List.sublistView(whole, 0, whole.length ~/ 2);

      // either answer is acceptable; not returning is not
      try {
        DocumentParser.spreadsheet(half, 'x.xlsx');
      } on Object {
        // an exception here is fine, the viewer shows its error state
      }
    });

    test('a zip with none of the parts we want comes back empty', () {
      final bytes = _zip(<String, String>{'readme.txt': 'hello'});
      expect(DocumentParser.spreadsheet(bytes, 'x.xlsx').isEmpty, isTrue);
      expect(DocumentParser.document(bytes, 'x.docx').isEmpty, isTrue);
    });
  });
}
