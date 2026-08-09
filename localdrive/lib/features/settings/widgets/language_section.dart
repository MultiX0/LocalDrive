import '../../../imports.dart';

/// The language choice, which is the same list on every breakpoint.
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final current = ref.watch(localeProvider);

    return ListView(
      padding: EdgeInsets.all(context.pagePadding),
      children: <Widget>[
        ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LdRadioRow(
                label: l10n.languageEnglish,
                selected: (current?.languageCode ?? 'en') == 'en',
                onTap: () =>
                    ref.read(localeProvider.notifier).set(const Locale('en')),
              ),
              LdRadioRow(
                label: l10n.languageArabic,
                selected: current?.languageCode == 'ar',
                onTap: () =>
                    ref.read(localeProvider.notifier).set(const Locale('ar')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
