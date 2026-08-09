import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_radii.dart';
import 'ld_button.dart';
import 'ld_icons.dart';
import 'ld_toast.dart';

/// An invite's code, a QR rendered locally, and a copyable link.
///
/// The QR is drawn on device by qr_flutter, so the code never leaves the
/// server to reach an image service.
class LdInviteCard extends StatelessWidget {
  const LdInviteCard({
    super.key,
    required this.code,
    required this.link,
    required this.copyCodeLabel,
    required this.copyLinkLabel,
    required this.copiedMessage,
    this.label,
    this.expiryLabel,
  });

  final String code;
  final String link;
  final String copyCodeLabel;
  final String copyLinkLabel;
  final String copiedMessage;
  final String? label;
  final String? expiryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.cardRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Text(label!, style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
          ],
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LdColors.foregroundPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: link,
                size: 168,
                version: QrVersions.auto,
                backgroundColor: LdColors.foregroundPrimary,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: LdColors.backgroundPrimary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: LdColors.backgroundPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: LdColors.backgroundPrimary,
              borderRadius: LdRadii.fieldRadius,
              border: Border.all(color: LdColors.strokeOutline),
            ),
            child: Center(
              child: SelectableText(
                code,
                style: theme.textTheme.titleLarge!.copyWith(letterSpacing: 3),
              ),
            ),
          ),
          if (expiryLabel != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              expiryLabel!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: LdButton.secondary(
                  label: copyCodeLabel,
                  glyph: LdGlyph.copy,
                  compact: true,
                  onPressed: () => _copy(context, code),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LdButton.secondary(
                  label: copyLinkLabel,
                  glyph: LdGlyph.link,
                  compact: true,
                  onPressed: () => _copy(context, link),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    LdToast.success(context, copiedMessage);
  }
}
