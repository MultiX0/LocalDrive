import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/core_providers.dart';

/// The runtime editable server settings.
class ServerSettingsModel {
  const ServerSettingsModel({
    required this.serverId,
    required this.serverName,
    required this.requireDeviceApproval,
    required this.enableLanDiscovery,
    required this.allowSelfRegistration,
    this.trashRetentionDays = 30,
  });

  final String serverId;
  final String serverName;
  final bool requireDeviceApproval;
  final bool enableLanDiscovery;
  final bool allowSelfRegistration;
  final int trashRetentionDays;

  factory ServerSettingsModel.fromJson(Map<String, dynamic> json) =>
      ServerSettingsModel(
        serverId: json['server_id'] as String? ?? '',
        serverName: json['server_name'] as String? ?? '',
        requireDeviceApproval:
            json['require_device_approval'] as bool? ?? false,
        enableLanDiscovery: json['enable_lan_discovery'] as bool? ?? false,
        allowSelfRegistration:
            json['allow_self_registration'] as bool? ?? false,
        trashRetentionDays: json['trash_retention_days'] as int? ?? 30,
      );
}

/// Reads the settings row and writes partial updates back, refreshing itself
/// from whatever the server confirms rather than assuming the write landed.
class ServerSettingsController extends AsyncNotifier<ServerSettingsModel> {
  @override
  Future<ServerSettingsModel> build() async {
    final json = await ref.watch(apiClientProvider).get(Api.serverSettings);
    return ServerSettingsModel.fromJson(json);
  }

  Future<void> apply({
    String? serverName,
    bool? requireDeviceApproval,
    bool? enableLanDiscovery,
    bool? allowSelfRegistration,
  }) async {
    state = const AsyncValue<ServerSettingsModel>.loading()
        .copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final json = await ref.read(apiClientProvider).patch(
        Api.serverSettings,
        body: <String, dynamic>{
          'server_name': ?serverName,
          'require_device_approval': ?requireDeviceApproval,
          'enable_lan_discovery': ?enableLanDiscovery,
          'allow_self_registration': ?allowSelfRegistration,
        },
      );
      return ServerSettingsModel.fromJson(json);
    });
  }
}

final serverSettingsProvider =
    AsyncNotifierProvider<ServerSettingsController, ServerSettingsModel>(
  ServerSettingsController.new,
);
