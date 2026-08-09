import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/ld_colors.dart';
import '../../../core/services/core_providers.dart';
import '../../../core/widgets/ld_icons.dart';
import '../../../l10n/generated/app_localizations.dart';

/// One row in the audit trail, already mapped to an icon and a tint so the
/// page stays free of a long switch.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String action;
  final int createdAt;
  final Map<String, dynamic> metadata;

  String get subject =>
      metadata['name'] as String? ?? metadata['username'] as String? ?? '';

  LdGlyph get glyph => switch (action.split('.').first) {
        'auth' => LdGlyph.person,
        'share' => LdGlyph.link,
        'permission' => LdGlyph.people,
        'device' => LdGlyph.device,
        'drive' || 'library' => LdGlyph.drive,
        'invite' => LdGlyph.qr,
        'user' => LdGlyph.person,
        'server' => LdGlyph.server,
        _ => LdGlyph.file,
      };

  Color get tint {
    if (action.contains('failed') ||
        action.contains('denied') ||
        action.contains('deleted') ||
        action.contains('formatted')) {
      return LdColors.accentWarning;
    }
    if (action.startsWith('share') || action.startsWith('permission')) {
      return LdColors.accentPrimary;
    }
    return LdColors.foregroundSecondary;
  }

  /// A plain sentence per action, falling back to the action name rather than
  /// rendering an empty row.
  String describe(BuildContext context) {
    final l10n = L10n.of(context);
    final name = subject;
    final label = switch (action) {
      'auth.login' => l10n.signIn,
      'auth.logout' => l10n.settingsSignOut,
      'auth.password_changed' => l10n.passwordChanged,
      'auth.password_reset' => l10n.resetPassword,
      'node.created' => l10n.newFolder,
      'node.uploaded' => l10n.upload,
      'node.downloaded' => l10n.download,
      'node.renamed' => l10n.actionRename,
      'node.moved' => l10n.actionMove,
      'node.trashed' => l10n.trash,
      'node.restored' => l10n.restore,
      'node.permanently_deleted' => l10n.permanentlyDelete,
      'share.created' => l10n.shareCreateLink,
      'share.revoked' => l10n.shareRevoke,
      'share.expired' => l10n.linkExpiration,
      'share.accessed' => l10n.share,
      'permission.granted' => l10n.sharedWithPerson,
      'permission.revoked' => l10n.shareRemoveAccess,
      'device.approved' => l10n.approve,
      'device.denied' => l10n.deny,
      'device.pending' => l10n.pendingApproval,
      'invite.created' => l10n.usersInviteSomeone,
      'drive.mounted' => l10n.storageUseThisDrive,
      'drive.ejected' => l10n.storageEject,
      'drive.formatted' => l10n.storageFormat,
      'drive.pooled' => l10n.storageCombine,
      _ => action,
    };
    return name.isEmpty ? label : '$label: $name';
  }

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as String? ?? '',
        action: json['action'] as String? ?? '',
        createdAt: json['created_at'] as int? ?? 0,
        metadata: (json['metadata'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      );
}

final activityProvider =
    FutureProvider.autoDispose<List<ActivityEntry>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final json = await api.get(Api.activity, query: <String, dynamic>{
    Api.qLimit: 100,
  });
  return (json['activity'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map(ActivityEntry.fromJson)
      .toList(growable: false);
});
