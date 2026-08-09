import '../../../../imports.dart';
import '../files_page.dart';

/// Mobile: a single stacked column, with the shell providing the floating
/// pill nav underneath.
class FilesPageMobile extends StatelessWidget {
  const FilesPageMobile({super.key, this.folderId, required this.filter});

  final String? folderId;
  final FilesFilter filter;

  @override
  Widget build(BuildContext context) {
    return FilesPageBody(folderId: folderId, filter: filter);
  }
}
