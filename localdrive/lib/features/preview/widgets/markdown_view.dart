import 'package:markdown/markdown.dart' as md;

import '../../../imports.dart';

/// The markdown reader. Parses with the `markdown` package, then renders the
/// resulting tree with this app's own widgets rather than a packaged
/// renderer's, so a markdown file looks like it belongs in this app instead
/// of borrowing another one's type scale, code blocks and tables.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubWeb,
      encodeHtml: false,
    ).parse(source);

    return Scrollbar(
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: context.pagePadding,
          vertical: 26,
        ),
        itemCount: nodes.length,
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            // a measured line length, the same as the document reader
            constraints: const BoxConstraints(maxWidth: 720),
            child: _Node(node: nodes[index]),
          ),
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.node, this.depth = 0});

  final md.Node node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final element = node;
    if (element is! md.Element) {
      return _paragraph(context, <md.Node>[node]);
    }

    switch (element.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _heading(context, element);

      case 'p':
        return _paragraph(context, element.children ?? const <md.Node>[]);

      case 'pre':
        return _code(context, element);

      case 'blockquote':
        return _quote(context, element);

      case 'ul':
      case 'ol':
        return _list(context, element);

      case 'hr':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 22),
          child: Divider(height: 1, color: LdColors.strokeOutline),
        );

      case 'table':
        return _table(context, element);

      default:
        return _paragraph(context, element.children ?? const <md.Node>[]);
    }
  }

  Widget _heading(BuildContext context, md.Element element) {
    final theme = Theme.of(context).textTheme;
    final level = int.tryParse(element.tag.substring(1)) ?? 1;
    final style = switch (level) {
      1 => theme.displaySmall,
      2 => theme.titleLarge,
      3 => theme.titleMedium,
      _ => theme.titleSmall,
    }!
        .copyWith(color: LdColors.foregroundPrimary, height: 1.3);

    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 8 : 26, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText.rich(
            TextSpan(children: _inline(context, element.children, style)),
            style: style,
          ),
          // the top two levels get a rule under them, which makes a
          // long readme skimmable rather than one undifferentiated column
          if (level <= 2) ...<Widget>[
            const SizedBox(height: 8),
            const Divider(height: 1, color: LdColors.strokeOutline),
          ],
        ],
      ),
    );
  }

  Widget _paragraph(BuildContext context, List<md.Node> children) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: LdColors.foregroundPrimary,
          height: 1.65,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SelectableText.rich(
        TextSpan(children: _inline(context, children, style)),
        style: style,
      ),
    );
  }

  Widget _code(BuildContext context, md.Element element) {
    final text = element.textContent.trimRight();
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
          color: LdColors.foregroundPrimary,
          height: 1.55,
          fontFamily: 'monospace',
          fontFamilyFallback: const <String>['Courier New'],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: LdColors.backgroundSunken,
          borderRadius: LdRadii.cardRadius,
          border: Border.all(color: LdColors.strokeOutline),
        ),
        child: SingleChildScrollView(
          // code never wraps: a wrapped line is a lie about where the line
          // breaks actually are
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: SelectableText(text, style: style),
        ),
      ),
    );
  }

  Widget _quote(BuildContext context, md.Element element) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 16, top: 4, bottom: 4),
        decoration: const BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: LdColors.accentPrimary, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final child in element.children ?? const <md.Node>[])
              _Node(node: child, depth: depth + 1),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, md.Element element) {
    final ordered = element.tag == 'ol';
    final items = (element.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((child) => child.tag == 'li')
        .toList();

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: depth * 18.0,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < items.length; i++)
            _ListItem(
              marker: ordered ? '${i + 1}.' : null,
              item: items[i],
              depth: depth,
            ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, md.Element element) {
    final rows = <List<md.Element>>[];
    for (final section in (element.children ?? const <md.Node>[])
        .whereType<md.Element>()) {
      for (final row
          in (section.children ?? const <md.Node>[]).whereType<md.Element>()) {
        rows.add(
          (row.children ?? const <md.Node>[]).whereType<md.Element>().toList(),
        );
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: LdRadii.cardRadius,
            border: Border.all(color: LdColors.strokeOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var r = 0; r < rows.length; r++)
                Container(
                  decoration: BoxDecoration(
                    color: r == 0
                        ? LdColors.backgroundElevated
                        : Colors.transparent,
                    border: r == 0
                        ? const Border(
                            bottom:
                                BorderSide(color: LdColors.strokeOutline),
                          )
                        : null,
                  ),
                  child: Row(
                    children: <Widget>[
                      for (final cell in rows[r])
                        Container(
                          width: 180,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Text(
                            cell.textContent,
                            style: r == 0
                                ? theme.labelMedium!.copyWith(
                                    color: LdColors.foregroundPrimary,
                                  )
                                : theme.bodySmall!.copyWith(
                                    color: LdColors.foregroundPrimary,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Inline spans: emphasis, code, links, and plain text.
  static List<InlineSpan> _inline(
    BuildContext context,
    List<md.Node>? children,
    TextStyle base,
  ) {
    final spans = <InlineSpan>[];

    void walk(List<md.Node> nodes, TextStyle style) {
      for (final node in nodes) {
        if (node is md.Text) {
          spans.add(TextSpan(text: node.text, style: style));
          continue;
        }
        if (node is! md.Element) continue;

        switch (node.tag) {
          case 'strong':
            walk(
              node.children ?? const <md.Node>[],
              style.copyWith(fontWeight: FontWeight.w600),
            );
          case 'em':
            walk(
              node.children ?? const <md.Node>[],
              style.copyWith(fontStyle: FontStyle.italic),
            );
          case 'del':
            walk(
              node.children ?? const <md.Node>[],
              style.copyWith(decoration: TextDecoration.lineThrough),
            );
          case 'code':
            spans.add(
              TextSpan(
                text: node.textContent,
                style: style.copyWith(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const <String>['Courier New'],
                  color: LdColors.fileCode,
                  backgroundColor: LdColors.backgroundSunken,
                ),
              ),
            );
          case 'a':
            // links are coloured but not tappable. A markdown preview opening
            // arbitrary URLs is a way to get someone somewhere they did not
            // mean to go, and this is a reader
            walk(
              node.children ?? const <md.Node>[],
              style.copyWith(color: LdColors.accentPrimary),
            );
          case 'br':
            spans.add(const TextSpan(text: '\n'));
          case 'img':
            spans.add(
              TextSpan(
                text: node.attributes['alt'] ?? '',
                style: style.copyWith(color: LdColors.foregroundSecondary),
              ),
            );
          default:
            walk(node.children ?? const <md.Node>[], style);
        }
      }
    }

    walk(children ?? const <md.Node>[], base);
    return spans;
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.marker,
    required this.item,
    required this.depth,
  });

  /// null for a bullet, "3." for a numbered item
  final String? marker;
  final md.Element item;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: LdColors.foregroundPrimary,
          height: 1.65,
        );

    // a nested list inside this item renders as its own block underneath,
    // rather than being flattened into the same line
    final inline = <md.Node>[];
    final nested = <md.Node>[];
    for (final child in item.children ?? const <md.Node>[]) {
      final tag = child is md.Element ? child.tag : '';
      if (tag == 'ul' || tag == 'ol') {
        nested.add(child);
      } else if (child is md.Element && tag == 'p') {
        inline.addAll(child.children ?? const <md.Node>[]);
      } else {
        inline.add(child);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 26,
                child: marker == null
                    ? const Padding(
                        padding: EdgeInsets.only(top: 9),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _Bullet(),
                        ),
                      )
                    : Text(
                        marker!,
                        style: style.copyWith(
                          color: LdColors.foregroundSecondary,
                        ),
                      ),
              ),
              Expanded(
                child: SelectableText.rich(
                  TextSpan(children: _Node._inline(context, inline, style)),
                  style: style,
                ),
              ),
            ],
          ),
          for (final child in nested)
            _Node(node: child, depth: depth + 1),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(
        color: LdColors.accentPrimary,
        shape: BoxShape.circle,
      ),
    );
  }
}
