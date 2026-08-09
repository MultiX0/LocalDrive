import '../../../imports.dart';
import '../db/document_parser.dart';

/// The word processor reader, for docx, odt and rtf.
///
/// It renders a reading column rather than a page. Reproducing the original's
/// page breaks and margins on a phone would be worse than useless: what
/// somebody wants from a document preview is to read it, and a fixed A4 page
/// scaled to a 390 point screen is unreadable.
///
/// So: the app's own type scale, a measured line length, and the formatting
/// that actually carries meaning, which is headings, emphasis and lists.
/// Everything else the file specifies about how it should look is dropped on
/// purpose.
class DocumentView extends StatelessWidget {
  const DocumentView({super.key, required this.document, required this.name});

  final TextDoc document;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    if (document.isEmpty) {
      return LdEmptyState(
        title: l10n.documentEmptyTitle,
        message: l10n.documentEmptyBody,
        glyph: LdGlyph.file,
        tint: LdColors.fileDocument,
      );
    }

    final blocks = document.blocks;

    return Scrollbar(
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: context.pagePadding,
          vertical: 28,
        ),
        itemCount: blocks.length,
        itemBuilder: (context, index) {
          final block = blocks[index];
          if (block.text.trim().isEmpty) {
            // a run of empty paragraphs is spacing in the original, not
            // content. One gap, not eight
            final previousBlank =
                index > 0 && blocks[index - 1].text.trim().isEmpty;
            return previousBlank
                ? const SizedBox.shrink()
                : const SizedBox(height: 14);
          }

          return Center(
            child: ConstrainedBox(
              // a measured line length. Text running the full width of a
              // desktop window is genuinely harder to read
              constraints: const BoxConstraints(maxWidth: 720),
              child: _Block(block: block),
            ),
          );
        },
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.block});

  final DocBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    final base = switch (block.headingLevel) {
      1 => theme.displaySmall,
      2 => theme.titleLarge,
      3 => theme.titleMedium,
      _ when block.isHeading => theme.titleSmall,
      _ => theme.bodyMedium,
    }!
        .copyWith(
      color: LdColors.foregroundPrimary,
      height: block.isHeading ? 1.3 : 1.65,
    );

    final content = SelectableText.rich(
      TextSpan(
        children: <TextSpan>[
          for (final span in block.spans)
            TextSpan(
              text: span.text,
              style: base.copyWith(
                fontWeight: span.bold ? FontWeight.w600 : null,
                fontStyle: span.italic ? FontStyle.italic : null,
                decoration:
                    span.underline ? TextDecoration.underline : null,
              ),
            ),
        ],
      ),
      style: base,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: block.isHeading ? 26 : 0,
        bottom: block.isHeading ? 10 : 12,
      ),
      child: block.bullet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: 9,
                    start: 6,
                    end: 14,
                  ),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: LdColors.accentPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}
