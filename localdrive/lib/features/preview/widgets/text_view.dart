import '../../../imports.dart';

/// The inline reader for plain text, markdown, and source files.
///
/// It reads a bounded prefix of the file rather than the whole thing. A log
/// that has grown to two hundred megabytes must not be able to take the app
/// down just because someone tapped it, so the read stops at a cap and the
/// screen says plainly that it did.
class TextView extends StatelessWidget {
  const TextView({
    super.key,
    required this.content,
    required this.truncated,
    required this.showLineNumbers,
  });

  /// the text that was actually read, already decoded
  final String content;

  /// true when the file was longer than the cap and this is only its start
  final bool truncated;

  /// source files get a gutter; prose does not, because it would only be noise
  final bool showLineNumbers;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final lines = content.split('\n');

    // monospace only for code. Prose in a fixed pitch face is harder to read,
    // and markdown is prose that happens to have punctuation in it
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
          color: LdColors.foregroundPrimary,
          height: 1.55,
          fontFamily: showLineNumbers ? 'monospace' : null,
          fontFamilyFallback:
              showLineNumbers ? const <String>['Courier New'] : null,
        );
    final gutterStyle = style.copyWith(color: LdColors.foregroundMuted);
    final gutterWidth = 16.0 + '${lines.length}'.length * 9.0;

    return Column(
      children: <Widget>[
        if (truncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: LdColors.backgroundElevated,
            child: Row(
              children: <Widget>[
                const LdIcon(
                  LdGlyph.info,
                  size: 16,
                  color: LdColors.foregroundSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.previewTruncated,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: LdColors.foregroundSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              // code lines are not wrapped: a wrapped line of code is a lie
              // about where the line breaks actually are
              scrollDirection:
                  showLineNumbers ? Axis.horizontal : Axis.vertical,
              child: showLineNumbers
                  ? SingleChildScrollView(
                      child: _Body(
                        lines: lines,
                        style: style,
                        gutterStyle: gutterStyle,
                        gutterWidth: gutterWidth,
                        showLineNumbers: true,
                      ),
                    )
                  : _Body(
                      lines: lines,
                      style: style,
                      gutterStyle: gutterStyle,
                      gutterWidth: gutterWidth,
                      showLineNumbers: false,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.lines,
    required this.style,
    required this.gutterStyle,
    required this.gutterWidth,
    required this.showLineNumbers,
  });

  final List<String> lines;
  final TextStyle style;
  final TextStyle gutterStyle;
  final double gutterWidth;
  final bool showLineNumbers;

  @override
  Widget build(BuildContext context) {
    if (!showLineNumbers) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SelectableText(lines.join('\n'), style: style),
      );
    }

    // text always runs left to right here even in an Arabic interface, because
    // the file's own bytes decide its direction, not the app chrome around it
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < lines.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: gutterWidth,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.right,
                      style: gutterStyle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(lines[i], style: style),
                  const SizedBox(width: 20),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
