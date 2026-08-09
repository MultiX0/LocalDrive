import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../widgets/ld_error_state.dart';
import '../../l10n/generated/app_localizations.dart';

/// Formatting that needs localized units, so a size or a timestamp reads
/// correctly in Arabic as well as English.
abstract final class LdFormat {
  /// A byte count, at the largest unit that keeps it readable.
  static String bytes(BuildContext context, int value) {
    final l10n = L10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 0,
    );
    final oneDecimal = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    );

    if (value < 1024) return l10n.sizeBytes(number.format(value));
    final kb = value / 1024;
    if (kb < 1024) return l10n.sizeKilobytes(number.format(kb.round()));
    final mb = kb / 1024;
    if (mb < 1024) {
      return l10n.sizeMegabytes(
        mb < 10 ? oneDecimal.format(mb) : number.format(mb.round()),
      );
    }
    final gb = mb / 1024;
    if (gb < 1024) return l10n.sizeGigabytes(oneDecimal.format(gb));
    return l10n.sizeTerabytes(oneDecimal.format(gb / 1024));
  }

  /// A timestamp, relative for anything recent and an actual date after that.
  static String relative(BuildContext context, int millis) {
    if (millis <= 0) return '';
    final l10n = L10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final moment = DateTime.fromMillisecondsSinceEpoch(millis);
    final elapsed = DateTime.now().difference(moment);

    if (elapsed.inMinutes < 1) return l10n.timeJustNow;
    if (elapsed.inMinutes < 60) return l10n.timeMinutesAgo(elapsed.inMinutes);
    if (elapsed.inHours < 24) return l10n.timeHoursAgo(elapsed.inHours);
    if (elapsed.inDays < 7) return l10n.timeDaysAgo(elapsed.inDays);
    if (moment.year == DateTime.now().year) {
      return DateFormat.MMMd(locale).format(moment);
    }
    return DateFormat.yMMMd(locale).format(moment);
  }

  /// An exact date and time, for a share expiry.
  static String dateTime(BuildContext context, int millis) {
    if (millis <= 0) return '';
    final locale = Localizations.localeOf(context).toString();
    final moment = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateFormat.yMMMd(locale).add_Hm().format(moment);
  }

  /// A plain integer in the locale's own numbering system, so a page counter
  /// in Arabic shows Arabic digits instead of Latin ones.
  static String count(BuildContext context, int value) {
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.decimalPattern(locale).format(value);
  }

  /// A media position or length as clock time. Hours only appear once there
  /// are hours, so a four minute track is not padded out to `00:04:12`.
  static String clock(Duration value) {
    final total = value.inSeconds < 0 ? 0 : value.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
  }

  /// A gallery heading: a day, a month or a year, in the locale's own
  /// calendar names.
  ///
  /// Today and yesterday are named rather than dated, because on a photo
  /// timeline that is what the two most recent headings almost always are and
  /// "14 Jul" for something taken this morning reads as older than it is.
  static String galleryHeading(
    BuildContext context,
    DateTime moment, {
    required bool day,
    required bool month,
  }) {
    final locale = Localizations.localeOf(context).toString();
    if (!day && !month) return DateFormat.y(locale).format(moment);
    if (!day) {
      final now = DateTime.now();
      return moment.year == now.year
          ? DateFormat.MMMM(locale).format(moment)
          : DateFormat.yMMMM(locale).format(moment);
    }

    final l10n = L10n.of(context);
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final startOfMoment = DateTime(moment.year, moment.month, moment.day);
    final daysApart = startOfToday.difference(startOfMoment).inDays;

    if (daysApart == 0) return l10n.galleryToday;
    if (daysApart == 1) return l10n.galleryYesterday;
    return moment.year == today.year
        ? DateFormat.MMMMd(locale).format(moment)
        : DateFormat.yMMMMd(locale).format(moment);
  }

  /// A percentage, for a transfer or a quota.
  static String percent(BuildContext context, double fraction) {
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.percentPattern(locale).format(fraction.clamp(0.0, 1.0));
  }

  /// The localized copy for every error kind, built once per screen and handed
  /// to LdAsync so no widget holds hardcoded English.
  static LdErrorCopy errorCopy(BuildContext context) {
    final l10n = L10n.of(context);
    return LdErrorCopy(
      retryLabel: l10n.actionRetry,
      titles: <LdErrorKind, String>{
        LdErrorKind.offline: l10n.errorOfflineTitle,
        LdErrorKind.unreachable: l10n.errorUnreachableTitle,
        LdErrorKind.permissionDenied: l10n.errorPermissionTitle,
        LdErrorKind.notFound: l10n.errorNotFoundTitle,
        LdErrorKind.quota: l10n.errorQuotaTitle,
        LdErrorKind.sessionExpired: l10n.errorSessionTitle,
        LdErrorKind.unexpected: l10n.errorUnexpectedTitle,
      },
      messages: <LdErrorKind, String>{
        LdErrorKind.offline: l10n.errorOfflineBody,
        LdErrorKind.unreachable: l10n.errorUnreachableBody,
        LdErrorKind.permissionDenied: l10n.errorPermissionBody,
        LdErrorKind.notFound: l10n.errorNotFoundBody,
        LdErrorKind.quota: l10n.errorQuotaBody,
        LdErrorKind.sessionExpired: l10n.errorSessionBody,
        LdErrorKind.unexpected: l10n.errorUnexpectedBody,
      },
    );
  }
}
