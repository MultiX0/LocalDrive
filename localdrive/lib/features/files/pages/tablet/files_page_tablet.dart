import '../../../../imports.dart';
import '../files_page.dart';

/// Tablet: the same layout as a phone, given more room.
///
/// This used to split in landscape, with a detail pane down the right. Nothing
/// ever selected into that pane, so it was a permanent placeholder showing the
/// page's own title and the same "upload a file to get started" sentence the
/// left half was already showing. Two identical empty states either side of a
/// divider reads as a rendering fault, not a layout.
///
/// The detail pane belongs on desktop, where there is width for it and where
/// selecting a file actually fills it. Here the list gets the whole screen.
class FilesPageTablet extends StatelessWidget {
  const FilesPageTablet({super.key, this.folderId, required this.filter});

  final String? folderId;
  final FilesFilter filter;

  @override
  Widget build(BuildContext context) {
    return FilesPageBody(folderId: folderId, filter: filter);
  }
}
