import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_motion.dart';
import 'ld_icons.dart';
import 'ld_skeleton.dart';

/// Every remote image in the app goes through this rather than a bare
/// `Image.network`: caches to disk so scrolling back up a grid does not
/// re-download a thumbnail, shows the app's shimmer instead of an empty
/// rectangle while it waits, and fades in instead of popping.
///
/// Also accepts a local file, so an offline-available image renders through
/// the same widget with the same shape and corners.
class LdRemoteImage extends StatelessWidget {
  const LdRemoteImage({
    super.key,
    required this.url,
    this.headers = const <String, String>{},
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.memCacheWidth,
    this.tint,
    this.localPath = '',
    this.fadeIn = true,
  });

  final String url;
  final Map<String, String> headers;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// decode at the size it will be drawn at, not at the source's own size. A
  /// grid of forty thumbnails decoded at full resolution is how a photo screen
  /// runs a device out of memory
  final int? memCacheWidth;

  /// the file type's colour, so a failed image still reads as the right kind
  /// of thing rather than as a generic error
  final Color? tint;

  /// set when this image is kept on the device, in which case nothing is
  /// fetched at all
  final String localPath;
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final image = localPath.isNotEmpty
        ? Image.file(
            File(localPath),
            fit: fit,
            width: width,
            height: height,
            cacheWidth: memCacheWidth,
            errorBuilder: (context, error, stack) => _Failed(tint: tint),
          )
        : CachedNetworkImage(
            imageUrl: url,
            httpHeaders: headers,
            fit: fit,
            width: width,
            height: height,
            memCacheWidth: memCacheWidth,
            fadeInDuration:
                fadeIn ? LdMotion.standard : Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, _) => const LdSkeleton(
              height: double.infinity,
              radius: 0,
            ),
            errorWidget: (context, _, _) => _Failed(tint: tint),
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  /// The provider, for the places that need one rather than a widget: a
  /// zoomable viewer, or a decoration.
  static ImageProvider provider({
    required String url,
    Map<String, String> headers = const <String, String>{},
    String localPath = '',
  }) {
    if (localPath.isNotEmpty) return FileImage(File(localPath));
    return CachedNetworkImageProvider(url, headers: headers);
  }
}

/// A thumbnail that would not load. It stays in the file type's own colour, so
/// a broken image still reads as the right kind of thing rather than as an
/// error that needs acting on: the file itself is fine, only its preview is
/// missing, and saying otherwise would be alarming for no reason.
class _Failed extends StatelessWidget {
  const _Failed({this.tint});

  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LdColors.backgroundElevated,
      child: Center(
        child: LdIcon(
          LdGlyph.image,
          size: 22,
          color: (tint ?? LdColors.foregroundSecondary).withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
