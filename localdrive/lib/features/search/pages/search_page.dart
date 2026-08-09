import 'dart:async';

import '../../../imports.dart';
import '../../files/providers/files_providers.dart';
import '../../files/widgets/shared/files_browser.dart';

/// Search across everything the caller can reach: their own files plus
/// anything inside a folder shared with them.
class SearchPage extends HookConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final controller = useTextEditingController();
    final term = useState('');

    // debounced, so typing does not fire a request per keystroke
    useEffect(() {
      Timer? timer;
      void listener() {
        timer?.cancel();
        timer = Timer(
          AppDurations.searchDebounce,
          () => term.value = controller.text.trim(),
        );
      }

      controller.addListener(listener);
      return () {
        timer?.cancel();
        controller.removeListener(listener);
      };
    }, <Object?>[controller]);

    return LdContentPane(
      maxWidth: LdContentPane.list,
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              8,
              context.pagePadding,
              12,
            ),
            child: Row(
              children: <Widget>[
                // search is opened from the files header, not from the tab
                // bar, so it hides the bar and brings its own way back
                LdTappable(
                  onTap: () => context.go(Routes.files),
                  borderRadius: BorderRadius.circular(22),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: LdIcon(LdGlyph.chevronLeft, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LdSearchField(
                    controller: controller,
                    hint: l10n.search,
                    autofocus: true,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: term.value.isEmpty
                ? LdEmptyState(
                    title: l10n.search,
                    message: l10n.emptySearchBody,
                    glyph: LdGlyph.search,
                  )
                : FilesBrowser(
                    query: FolderQuery(query: term.value),
                    emptyGlyph: LdGlyph.search,
                    emptyTitle: l10n.emptySearchTitle,
                    emptyBody: l10n.emptySearchBody,
                  ),
          ),
        ],
      ),
    );
  }
}
