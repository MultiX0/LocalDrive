import '../../../../imports.dart';
import '../../../files/providers/files_providers.dart';
import '../../../files/widgets/shared/files_browser.dart';

/// Shared with me, on a phone: a stacked title above the listing, with the
/// shell's pill bar underneath.
class SharedPageMobile extends StatelessWidget {
  const SharedPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      children: <Widget>[
        // a tab destination, so no back control: there is nothing above it
        LdPageHeader(title: l10n.sharedWithMe),
        Expanded(
          child: FilesBrowser(
            query: FolderQuery(filter: NodeFilter.shared),
            emptyGlyph: LdGlyph.shared,
            emptyTitle: l10n.emptySharedTitle,
            emptyBody: l10n.emptySharedBody,
          ),
        ),
      ],
    );
  }
}
