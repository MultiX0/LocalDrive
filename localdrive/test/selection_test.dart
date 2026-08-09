import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localdrive/features/files/providers/files_providers.dart';

/// The desktop selection rules, which are the ones a file manager is judged on.
void main() {
  late ProviderContainer container;
  late SelectionController selection;

  const ordered = <String>['a', 'b', 'c', 'd', 'e'];

  setUp(() {
    container = ProviderContainer();
    selection = container.read(selectionProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('a plain click replaces the selection rather than adding to it', () {
    selection.only('a');
    selection.only('c');
    expect(container.read(selectionProvider), <String>{'c'});
  });

  test('ctrl click adds one and takes it away again', () {
    selection.only('a');
    selection.toggleAt('c');
    expect(container.read(selectionProvider), <String>{'a', 'c'});

    selection.toggleAt('c');
    expect(container.read(selectionProvider), <String>{'a'});
  });

  test('shift click takes the run between the anchor and the click', () {
    selection.only('b');
    selection.selectRange('d', ordered);
    expect(container.read(selectionProvider), <String>{'b', 'c', 'd'});
  });

  test('a run works upwards as well as downwards', () {
    selection.only('d');
    selection.selectRange('b', ordered);
    expect(container.read(selectionProvider), <String>{'b', 'c', 'd'});
  });

  test('shift clicking again from the same anchor resizes the run', () {
    selection.only('b');
    selection.selectRange('e', ordered);
    expect(container.read(selectionProvider), <String>{'b', 'c', 'd', 'e'});

    // the anchor has not moved, so this shrinks the run rather than starting
    // a new one from where the last shift click landed
    selection.selectRange('c', ordered);
    expect(container.read(selectionProvider), <String>{'b', 'c'});
  });

  test('a run with nothing anchored selects only what was clicked', () {
    selection.selectRange('c', ordered);
    expect(container.read(selectionProvider), <String>{'c'});
  });

  test('ctrl click moves the anchor, so the next run measures from it', () {
    selection.only('a');
    selection.toggleAt('d');
    selection.selectRange('b', ordered);
    expect(container.read(selectionProvider), <String>{'b', 'c', 'd'});
  });

  test('a marquee replaces the selection, and keeps it when additive', () {
    selection.only('a');
    selection.setMarquee(<String>{'c', 'd'}, additive: false);
    expect(container.read(selectionProvider), <String>{'c', 'd'});

    selection.setMarquee(
      <String>{'e'},
      additive: true,
      base: <String>{'a', 'b'},
    );
    expect(container.read(selectionProvider), <String>{'a', 'b', 'e'});
  });

  test('clearing forgets the anchor, so no stale run survives it', () {
    selection.only('b');
    selection.clear();
    selection.selectRange('d', ordered);
    expect(container.read(selectionProvider), <String>{'d'});
  });
}
