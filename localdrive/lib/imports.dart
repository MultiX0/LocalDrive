/// The common surface every feature file needs, in one import.
///
/// Keep this lean: only stable, broadly used exports. Feature-local files are
/// imported directly, not through here.
library;

export 'package:flutter/foundation.dart' show kIsWeb;
export 'package:flutter/material.dart' hide SearchController;
export 'package:flutter_hooks/flutter_hooks.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:hooks_riverpod/hooks_riverpod.dart';
export 'package:go_router/go_router.dart';

export 'core/constants/api_endpoints.dart';
export 'core/constants/breakpoints.dart';
export 'core/constants/ld_colors.dart';
export 'core/constants/ld_motion.dart';
export 'core/constants/ld_radii.dart';
export 'core/constants/ld_typography.dart';
export 'core/constants/storage_keys.dart';

export 'core/enums/file_category.dart';
export 'core/enums/transfer_status.dart';

export 'core/router/routes.dart';

export 'core/services/api_exception.dart';
export 'core/services/core_providers.dart';
export 'core/services/websocket_service.dart' show LdEvent, LdConnectionState;

export 'core/theme/ld_theme.dart';

export 'core/utils/formatters.dart';

export 'core/widgets/ld_async.dart';
export 'core/widgets/ld_avatar.dart';
export 'core/widgets/ld_bottom_nav.dart';
export 'core/widgets/ld_bottom_sheet.dart';
export 'core/widgets/ld_hoverable.dart';
export 'core/widgets/zoom_on_scroll.dart';
export 'core/widgets/ld_button.dart';
export 'core/widgets/ld_color_picker.dart';
export 'core/widgets/ld_context_menu.dart';
export 'core/widgets/ld_controls.dart';
export 'core/widgets/ld_date_picker.dart';
export 'core/widgets/ld_desktop_scaffold.dart';
export 'core/widgets/ld_empty_state.dart';
export 'core/widgets/ld_error_state.dart';
export 'core/widgets/ld_file_icon.dart';
export 'core/widgets/ld_icons.dart';
export 'core/widgets/ld_invite_card.dart';
export 'core/widgets/ld_language_toggle.dart';
export 'core/widgets/ld_logo.dart';
export 'core/widgets/ld_node_list_item.dart';
export 'core/widgets/ld_progress_bar.dart';
export 'core/widgets/ld_radar.dart';
export 'core/widgets/ld_refresh.dart';
export 'core/widgets/ld_remote_image.dart';
export 'core/widgets/ld_responsive.dart';
export 'core/widgets/ld_scaffold.dart';
export 'core/widgets/ld_send_flight.dart';
export 'core/widgets/ld_skeleton.dart';
export 'core/widgets/ld_spinner.dart';
export 'core/widgets/ld_content_pane.dart';
export 'core/widgets/ld_page_header.dart';
export 'core/widgets/ld_tappable.dart';
export 'core/widgets/ld_text_field.dart';
export 'core/widgets/ld_toast.dart';
export 'core/widgets/ld_window_bar.dart';

export 'l10n/generated/app_localizations.dart';
