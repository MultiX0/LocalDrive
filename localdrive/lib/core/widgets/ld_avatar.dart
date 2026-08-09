import 'package:flutter/material.dart';

import '../constants/ld_colors.dart';

/// A person, drawn as a deterministic gradient plus their initials. The same
/// seed always produces the same face, so an avatar is recognizable across
/// devices without the server ever storing an image.
class LdAvatar extends StatelessWidget {
  const LdAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 32,
    this.showBorder = false,
  });

  final String name;
  final String seed;
  final double size;
  final bool showBorder;

  /// The gradient for one seed. Hashed rather than random so it is stable.
  static List<Color> gradientFor(String seed) {
    final hash = _hash(seed.isEmpty ? 'localdrive' : seed);
    final hue = (hash % 360).toDouble();
    final secondHue = (hue + 38) % 360;
    return <Color>[
      HSLColor.fromAHSL(1, hue, 0.52, 0.56).toColor(),
      HSLColor.fromAHSL(1, secondHue, 0.58, 0.42).toColor(),
    ];
  }

  static int _hash(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static String initialsOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.length == 1) {
      final single = parts.first;
      return single.characters.take(2).toString().toUpperCase();
    }
    return parts
        .take(2)
        .map((p) => p.characters.first)
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = gradientFor(seed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: showBorder
            ? Border.all(color: LdColors.backgroundPrimary, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: LdColors.foregroundPrimary,
              fontSize: size * 0.36,
              height: 1,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

/// An avatar with a small live dot, for anyone currently on the same network.
class LdNearbyAvatar extends StatelessWidget {
  const LdNearbyAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 40,
    this.nearby = false,
  });

  final String name;
  final String seed;
  final double size;
  final bool nearby;

  @override
  Widget build(BuildContext context) {
    if (!nearby) return LdAvatar(name: name, seed: seed, size: size);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        LdAvatar(name: name, seed: seed, size: size),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.3,
            height: size * 0.3,
            decoration: BoxDecoration(
              color: LdColors.fileSpreadsheet,
              shape: BoxShape.circle,
              border: Border.all(color: LdColors.backgroundPrimary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
