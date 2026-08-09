import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:photo_view/photo_view.dart';

import '../../../imports.dart';
import '../../files/models/node_model.dart';
import '../../files/providers/files_providers.dart';
import '../../files/widgets/shared/node_actions.dart';
import '../../offline/controller/offline_controller.dart';
import '../../share/providers/share_providers.dart';
import '../../upload/controller/transfer_controller.dart';
import '../db/document_parser.dart';
import '../widgets/audio_view.dart';
import '../widgets/document_view.dart';
import '../widgets/markdown_view.dart';
import '../widgets/sheet_view.dart';
import '../widgets/pdf_view.dart';
import '../widgets/text_view.dart';
import '../widgets/video_view.dart';

/// The file viewer: inline for image, video, audio, pdf and text, a type icon
/// plus download for anything else.
///
/// It doubles as the public share screen, which needs no session at all.
class PreviewPage extends ConsumerWidget {
  const PreviewPage({super.key, required this.nodeId}) : shareToken = '';

  const PreviewPage.publicShare({super.key, required String token})
    : nodeId = '',
      shareToken = token;

  final String nodeId;
  final String shareToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shareToken.isNotEmpty) {
      return _PublicSharePreview(token: shareToken);
    }

    final l10n = L10n.of(context);
    final node = ref.watch(nodeProvider(nodeId));

    return LdScaffold(
      showBack: true,
      title: node.maybeWhen(data: (n) => n.name, orElse: () => ''),
      subtitle: node.maybeWhen(
        data: (n) => LdFormat.bytes(context, n.sizeBytes),
        orElse: () => null,
      ),
      actions: <Widget>[
        node.maybeWhen(
          data: (n) => LdUtilityButton(
            glyph: LdGlyph.download,
            tooltip: l10n.download,
            onPressed: () => downloadNodes(context, ref, <NodeModel>[n]),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        node.maybeWhen(
          data: (n) => Builder(
            builder: (context) => LdUtilityButton(
              glyph: LdGlyph.more,
              tooltip: l10n.moreActions,
              onPressed: () => showNodeActions(
                context,
                ref,
                n,
                anchorOf(context),
                alreadyOpen: true,
              ),
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      body: LdAsync<NodeModel>(
        value: node,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(nodeProvider(nodeId)),
        loading: const Center(child: LdSpinner(size: 34)),
        data: (n) => _PreviewBody(node: n),
      ),
    );
  }
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final db = ref.watch(filesDbProvider);
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;
    final localPath =
        ref.watch(offlineLocalPathProvider(node.id)).valueOrNull ?? '';

    // kept on this device: it opens from local bytes, with no spinner and no
    // wait, which is the entire promise offline availability makes
    if (localPath.isNotEmpty) {
      return _LocalBody(node: node, path: localPath);
    }

    // not kept, and no connection to fetch it with. Say that plainly rather
    // than spinning forever or looking broken
    if (!online) {
      return LdEmptyState(
        title: node.name,
        message: l10n.offlineNeedsConnection,
        glyph: LdGlyph.offline,
        tint: node.category.tint,
        actionLabel: l10n.offlineMakeAvailable,
        onAction: OfflineController.isSupported
            ? () => ref.read(offlineControllerProvider.notifier).mark(node)
            : null,
      );
    }

    final url = db.downloadUrl(node.id, inline: true);

    return switch (node.category) {
      FileCategory.image => _ImageView(url: url, headers: db.authHeaders),
      FileCategory.video => VideoView(url: url, headers: db.authHeaders),
      FileCategory.audio => AudioView(
        url: url,
        headers: db.authHeaders,
        name: node.name,
      ),
      FileCategory.pdf => PdfView(
        url: url,
        headers: db.authHeaders,
        name: node.name,
      ),
      // markdown is a text file, but reading it as one throws away the only
      // thing that makes it markdown
      FileCategory.text when _isMarkdown(node.name) => _TextLoader(
        node: node,
        markdown: true,
      ),
      // code keeps its line gutter; prose reads better without
      FileCategory.text || FileCategory.code => _TextLoader(node: node),
      FileCategory.spreadsheet => _SheetLoader(node: node),
      FileCategory.document ||
      FileCategory.presentation => _DocumentLoader(node: node),
      _ => LdEmptyState(
        title: l10n.previewCannotPreview,
        message: l10n.previewDownloadToOpen,
        glyph: LdGlyph.file,
        tint: node.category.tint,
        actionLabel: l10n.download,
        onAction: () => downloadNodes(context, ref, <NodeModel>[node]),
      ),
    };
  }
}

/// The same viewers, reading from a file on this device rather than over the
/// network. This is the path an offline available file takes, and it is why
/// opening one costs nothing even with the radio off.
class _LocalBody extends StatelessWidget {
  const _LocalBody({required this.node, required this.path});

  final NodeModel node;
  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return switch (node.category) {
      FileCategory.image => PhotoView(
        imageProvider: FileImage(File(path)),
        backgroundDecoration: const BoxDecoration(
          color: LdColors.backgroundPrimary,
        ),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
      ),
      FileCategory.video => VideoView(localPath: path),
      FileCategory.audio => AudioView(localPath: path, name: node.name),
      FileCategory.pdf => PdfView(localPath: path, name: node.name),
      FileCategory.text ||
      FileCategory.code => _LocalText(node: node, path: path),
      FileCategory.spreadsheet ||
      FileCategory.document => _LocalDocument(node: node, path: path),
      _ => LdEmptyState(
        title: l10n.previewCannotPreview,
        message: l10n.previewDownloadToOpen,
        glyph: LdGlyph.file,
        tint: node.category.tint,
      ),
    };
  }
}

/// The office formats, read from a file on this device rather than the
/// network. Same parser, same viewers.
class _LocalDocument extends StatelessWidget {
  const _LocalDocument({required this.node, required this.path});

  final NodeModel node;
  final String path;

  @override
  Widget build(BuildContext context) {
    final spreadsheet = node.category == FileCategory.spreadsheet;

    return FutureBuilder<Object>(
      future: File(path).readAsBytes().then(
        (bytes) => compute<_Payload, Object>(
          spreadsheet ? _parseSheet : _parseDocument,
          (bytes: bytes, name: node.name),
        ),
      ),
      builder: (context, snapshot) {
        final document = snapshot.data;
        if (document == null) return const Center(child: LdSpinner(size: 34));
        return document is SpreadsheetDoc
            ? SheetView(document: document)
            : DocumentView(document: document as TextDoc, name: node.name);
      },
    );
  }
}

class _LocalText extends StatelessWidget {
  const _LocalText({required this.node, required this.path});

  final NodeModel node;
  final String path;

  /// the same cap the network reader uses, for the same reason: a log that has
  /// grown to hundreds of megabytes must not be able to take the app down
  static const int maxBytes = 512 * 1024;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String text, bool truncated})>(
      future: _read(),
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result == null) return const Center(child: LdSpinner(size: 34));
        return TextView(
          content: result.text,
          truncated: result.truncated,
          showLineNumbers: node.category == FileCategory.code,
        );
      },
    );
  }

  Future<({String text, bool truncated})> _read() async {
    final file = File(path);
    final length = await file.length();
    if (length <= maxBytes) {
      return (text: await file.readAsString(), truncated: false);
    }
    final handle = await file.open();
    try {
      final bytes = await handle.read(maxBytes);
      return (text: utf8.decode(bytes, allowMalformed: true), truncated: true);
    } finally {
      await handle.close();
    }
  }
}

/// Whether a name is markdown. Both extensions, because both are common and
/// neither is more correct than the other.
bool _isMarkdown(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.md') || lower.endsWith('.markdown');
}

/// One file's bytes and the name they were parsed under, which is what tells
/// the parser whether it is looking at xlsx, ods or csv.
typedef _Payload = ({Uint8List bytes, String name});

/// The two parses, at the top level because that is what `compute` needs: an
/// isolate cannot be handed a closure over the widget tree.
SpreadsheetDoc _parseSheet(_Payload payload) =>
    DocumentParser.spreadsheet(payload.bytes, payload.name);

TextDoc _parseDocument(_Payload payload) =>
    DocumentParser.document(payload.bytes, payload.name);

/// Fetches a spreadsheet and shows it.
class _SheetLoader extends StatelessWidget {
  const _SheetLoader({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    return _BytesLoader<SpreadsheetDoc>(
      node: node,
      parse: _parseSheet,
      render: (document) => SheetView(document: document),
    );
  }
}

/// Fetches a document and shows it.
class _DocumentLoader extends StatelessWidget {
  const _DocumentLoader({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    return _BytesLoader<TextDoc>(
      node: node,
      parse: _parseDocument,
      render: (document) => DocumentView(document: document, name: node.name),
    );
  }
}

/// Fetch, then parse on a background isolate, then render.
///
/// A twenty megabyte spreadsheet takes real time to unzip and walk. Parsing
/// on the UI thread would drop every frame until it finished, so `compute`
/// moves it to a background isolate instead.
class _BytesLoader<T> extends ConsumerWidget {
  const _BytesLoader({
    required this.node,
    required this.parse,
    required this.render,
  });

  final NodeModel node;
  final T Function(_Payload payload) parse;
  final Widget Function(T document) render;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(nodeBytesProvider(node.id));

    return LdAsync<Uint8List>(
      value: bytes,
      errorCopy: LdFormat.errorCopy(context),
      onRetry: () => ref.invalidate(nodeBytesProvider(node.id)),
      loading: const Center(child: LdSpinner(size: 34)),
      data: (data) => FutureBuilder<T>(
        future: compute(parse, (bytes: data, name: node.name)),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final l10n = L10n.of(context);
            return LdErrorState(
              kind: LdErrorKind.unexpected,
              title: l10n.previewCannotOpenTitle,
              message: l10n.previewCannotOpenBody,
            );
          }
          final document = snapshot.data;
          if (document == null) {
            return const Center(child: LdSpinner(size: 34));
          }
          return render(document);
        },
      ),
    );
  }
}

/// Fetches the bounded prefix and hands it to the reader. Kept separate so the
/// reader itself stays a pure widget over text it was given.
class _TextLoader extends ConsumerWidget {
  const _TextLoader({required this.node, this.markdown = false});

  final NodeModel node;
  final bool markdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(nodeTextProvider(node.id));

    return LdAsync<({String text, bool truncated})>(
      value: content,
      errorCopy: LdFormat.errorCopy(context),
      onRetry: () => ref.invalidate(nodeTextProvider(node.id)),
      loading: const Center(child: LdSpinner(size: 34)),
      data: (result) => markdown
          ? MarkdownView(source: result.text)
          : TextView(
              content: result.text,
              truncated: result.truncated,
              showLineNumbers: node.category == FileCategory.code,
            ),
    );
  }
}

class _ImageView extends StatefulWidget {
  const _ImageView({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  State<_ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<_ImageView> {
  late final PhotoViewController _controller = PhotoViewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZoomOnScroll(
      controller: _controller,
      child: PhotoView(
        controller: _controller,
        imageProvider: LdRemoteImage.provider(
          url: widget.url,
          headers: widget.headers,
        ),
        backgroundDecoration: const BoxDecoration(
          color: LdColors.backgroundPrimary,
        ),
        // the branded spinner rather than photo_view's own progress ring
        loadingBuilder: (context, event) => const Center(child: LdSpinner()),
        errorBuilder: (context, error, stack) => LdErrorState(
          kind: LdErrorKind.unexpected,
          title: L10n.of(context).errorUnexpectedTitle,
          message: L10n.of(context).errorUnexpectedBody,
        ),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
      ),
    );
  }
}

/// The public share view. No session, no chrome beyond what the link allows.
class _PublicSharePreview extends ConsumerWidget {
  const _PublicSharePreview({required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final meta = ref.watch(publicShareProvider(token));

    return LdScaffold(
      titleWidget: LdWordmark(title: l10n.appName),
      body: LdAsync<PublicShareModel>(
        value: meta,
        errorCopy: LdFormat.errorCopy(context),
        onRetry: () => ref.invalidate(publicShareProvider(token)),
        loading: const Center(child: LdSpinner(size: 34)),
        data: (share) => _PublicShareBody(token: token, share: share),
      ),
    );
  }
}

class _PublicShareBody extends ConsumerWidget {
  const _PublicShareBody({required this.token, required this.share});

  final String token;
  final PublicShareModel share;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final url = ref.watch(shareDbProvider).publicDownloadUrl(token);

    // a public link carries no session, so these render with no auth headers
    final body = switch (share.category) {
      FileCategory.image => _ImageView(
        url: url,
        headers: const <String, String>{},
      ),
      FileCategory.video => VideoView(url: url),
      FileCategory.audio => AudioView(url: url, name: share.name),
      FileCategory.pdf => PdfView(url: url, name: share.name),
      _ => LdEmptyState(
        title: share.name,
        message: l10n.previewDownloadToOpen,
        glyph: LdGlyph.file,
        tint: share.category.tint,
      ),
    };

    return Column(
      children: <Widget>[
        Expanded(child: body),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  share.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  LdFormat.bytes(context, share.sizeBytes),
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: LdColors.foregroundSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                if (share.allowDownload)
                  LdButton(
                    label: l10n.download,
                    glyph: LdGlyph.download,
                    onPressed: () => ref
                        .read(transferControllerProvider.notifier)
                        .enqueuePublicDownload(
                          token: token,
                          name: share.name,
                          sizeBytes: share.sizeBytes,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
