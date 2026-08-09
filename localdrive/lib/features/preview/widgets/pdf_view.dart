import 'package:pdfrx/pdfrx.dart';

import '../../../imports.dart';

/// The inline PDF reader.
///
/// It loads over the network with range access rather than downloading the
/// whole file first, which is the only way a two hundred page scan opens on a
/// phone without waiting. The server's download endpoint answers Range
/// requests, so this is a real streamed read, not a trick.
class PdfView extends StatefulWidget {
  const PdfView({
    super.key,
    required this.name,
    this.url = '',
    this.headers = const <String, String>{},
    this.localPath = '',
  }) : assert(
          url != '' || localPath != '',
          'a reader needs either a url to stream or a file to open',
        );

  final String url;
  final Map<String, String> headers;
  final String name;

  /// set when this file is kept on the device, in which case nothing is
  /// fetched and the reader opens straight from disk
  final String localPath;

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  final PdfViewerController _controller = PdfViewerController();
  int _page = 1;
  int _pageCount = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: widget.localPath.isNotEmpty
              ? PdfViewer.file(
                  widget.localPath,
                  controller: _controller,
                  params: _params(context),
                )
              : PdfViewer.uri(
                  Uri.parse(widget.url),
                  controller: _controller,
                  headers: widget.headers,
                  // range access is not available on web, where the browser
                  // fetches the whole body; everywhere else this keeps it fast
                  preferRangeAccess: !kIsWeb,
                  params: _params(context),
                ),
        ),
        if (_pageCount > 0)
          _PageBar(
            page: _page,
            pageCount: _pageCount,
            onPrevious: _page > 1
                ? () => _controller.goToPage(pageNumber: _page - 1)
                : null,
            onNext: _page < _pageCount
                ? () => _controller.goToPage(pageNumber: _page + 1)
                : null,
          ),
      ],
    );
  }

  PdfViewerParams _params(BuildContext context) {
    final l10n = L10n.of(context);
    return PdfViewerParams(
      backgroundColor: LdColors.backgroundSunken,
      margin: 12,
      maxScale: 6,
      loadingBannerBuilder: (context, downloaded, total) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LdSpinner(size: 34),
            if (total != null && total > 0) ...<Widget>[
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: LdProgressBar(value: downloaded / total),
              ),
            ],
          ],
        ),
      ),
      errorBannerBuilder: (context, error, stack, documentRef) => LdErrorState(
        kind: LdErrorKind.unexpected,
        title: l10n.errorUnexpectedTitle,
        message: l10n.errorUnexpectedBody,
      ),
      onViewerReady: (document, controller) {
        if (!mounted) return;
        setState(() => _pageCount = document.pages.length);
      },
      onPageChanged: (pageNumber) {
        if (!mounted || pageNumber == null) return;
        setState(() => _page = pageNumber);
      },
    );
  }
}

/// Where you are in the document, and the two ways to move one page.
///
/// Page numbers are formatted through the localized number system, so an
/// Arabic reader sees Arabic digits rather than a bare "3 / 240".
class _PageBar extends StatelessWidget {
  const _PageBar({
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: LdColors.backgroundPrimary,
        border: Border(top: BorderSide(color: LdColors.strokeOutline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            LdUtilityButton(
              glyph: LdGlyph.chevronLeft,
              tooltip: l10n.previewPreviousPage,
              onPressed: onPrevious,
            ),
            const SizedBox(width: 18),
            Text(
              l10n.previewPageOf(
                LdFormat.count(context, page),
                LdFormat.count(context, pageCount),
              ),
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: LdColors.foregroundSecondary,
                  ),
            ),
            const SizedBox(width: 18),
            LdUtilityButton(
              glyph: LdGlyph.chevronRight,
              tooltip: l10n.previewNextPage,
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
