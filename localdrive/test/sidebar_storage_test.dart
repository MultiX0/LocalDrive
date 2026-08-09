import 'package:flutter_test/flutter_test.dart';

/// The sidebar's remaining-space rule, kept here so the arithmetic can be
/// checked without building a widget tree.
///
/// Used is this account's own files. Free is the shared disk. The space this
/// account can actually still use is whichever of the two limits binds first.
({int remaining, double fraction, bool diskIsTheLimit}) headroom({
  required int used,
  required int quotaBytes,
  required int diskFree,
}) {
  final hasQuota = quotaBytes > 0;
  final quotaLeft = hasQuota ? quotaBytes - used : null;

  final limit = switch ((quotaLeft, diskFree)) {
    (null, final free) => free,
    (final left, < 0) => left!,
    (final left, final free) => left! < free ? left : free,
  };
  final remaining = limit < 0 ? 0 : limit;

  final capacity = used + remaining;
  return (
    remaining: remaining,
    fraction: capacity <= 0 ? 0.0 : (used / capacity).clamp(0.0, 1.0),
    diskIsTheLimit: hasQuota && diskFree >= 0 && diskFree < quotaLeft!,
  );
}

const int gb = 1024 * 1024 * 1024;

void main() {
  group('no quota', () {
    test('the disk is the only limit', () {
      final r = headroom(used: 10 * gb, quotaBytes: 0, diskFree: 90 * gb);
      expect(r.remaining, 90 * gb);
      expect(r.fraction, closeTo(0.1, 0.001));
      expect(r.diskIsTheLimit, isFalse);
    });

    test('a full disk reads as full', () {
      final r = headroom(used: 50 * gb, quotaBytes: 0, diskFree: 0);
      expect(r.remaining, 0);
      expect(r.fraction, 1.0);
    });
  });

  group('with a quota', () {
    test('the quota binds when the disk has plenty', () {
      final r = headroom(used: 2 * gb, quotaBytes: 10 * gb, diskFree: 500 * gb);
      expect(r.remaining, 8 * gb);
      expect(r.fraction, closeTo(0.2, 0.001));
      expect(r.diskIsTheLimit, isFalse);
    });

    test('the disk binds when it is lower than the quota allows', () {
      // the case this exists for: a generous quota on an almost full disk
      final r = headroom(used: 1 * gb, quotaBytes: 100 * gb, diskFree: 2 * gb);
      expect(r.remaining, 2 * gb, reason: 'not the 99 GB the quota implies');
      expect(r.diskIsTheLimit, isTrue);
    });

    test('a quota already exceeded never reports negative space', () {
      // an admin can lower a quota below what someone already stores
      final r = headroom(used: 20 * gb, quotaBytes: 10 * gb, diskFree: 50 * gb);
      expect(r.remaining, 0);
      expect(r.fraction, 1.0);
    });
  });

  group('unknown disk', () {
    test('falls back to the quota when the disk cannot be read', () {
      final r = headroom(used: 1 * gb, quotaBytes: 10 * gb, diskFree: -1);
      expect(r.remaining, 9 * gb);
      expect(r.diskIsTheLimit, isFalse);
    });
  });

  test('a brand new account on an empty server is not shown as full', () {
    final r = headroom(used: 0, quotaBytes: 0, diskFree: 100 * gb);
    expect(r.fraction, 0.0);
  });

  test('real disk sizes survive, on the web as well as the vm', () {
    // 14 GB free on a 474 GB disk, the numbers from an actual server. An
    // earlier version clamped with `1 << 62`, which is fine here and wrong in
    // a browser: dart compiles a shift to javascript's 32 bit bitwise
    // operator, so the bound wrapped and this came back as zero free.
    const diskFree = 15088484352;
    final r = headroom(used: 312224, quotaBytes: 0, diskFree: diskFree);
    expect(r.remaining, diskFree);
    expect(r.fraction, lessThan(0.01));
  });

  test('used stays this account, free stays the whole disk', () {
    // two accounts on one server: different used, identical free
    final me = headroom(used: 5 * gb, quotaBytes: 0, diskFree: 40 * gb);
    final you = headroom(used: 30 * gb, quotaBytes: 0, diskFree: 40 * gb);
    expect(me.remaining, you.remaining);
    expect(me.fraction, isNot(equals(you.fraction)));
  });
}
