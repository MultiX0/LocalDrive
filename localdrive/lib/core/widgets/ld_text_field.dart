import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/ld_colors.dart';
import '../constants/ld_radii.dart';
import 'ld_icons.dart';
import 'ld_tappable.dart';

/// How a field is drawn: the giant borderless auth field, or a standard
/// bordered inline one.
enum LdFieldStyle { giant, inline }

/// The one text field. Nothing in the app uses a bare TextField.
class LdTextField extends StatefulWidget {
  const LdTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.style = LdFieldStyle.inline,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.errorText,
    this.helperText,
    this.prefixGlyph,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.textAlign,
    this.autofillHints,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final LdFieldStyle style;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final String? errorText;
  final String? helperText;
  final LdGlyph? prefixGlyph;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign? textAlign;
  final Iterable<String>? autofillHints;

  @override
  State<LdTextField> createState() => _LdTextFieldState();
}

class _LdTextFieldState extends State<LdTextField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChanged);
  bool _focused = false;
  bool _revealed = false;

  void _onFocusChanged() {
    if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGiant = widget.style == LdFieldStyle.giant;
    final theme = Theme.of(context);
    final textStyle =
        isGiant ? theme.textTheme.displayMedium : theme.textTheme.bodyLarge;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscure && !_revealed,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      textAlign: widget.textAlign ??
          (isGiant ? TextAlign.center : TextAlign.start),
      style: textStyle,
      cursorColor: LdColors.accentPrimary,
      cursorRadius: const Radius.circular(2),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        counterText: '',
        hintText: widget.hint,
        // a hint is meant to be read before you type, so it gets readable
        // contrast rather than the muted tone used for hairlines
        hintStyle: textStyle?.copyWith(color: LdColors.foregroundSecondary),
        contentPadding: EdgeInsets.symmetric(vertical: isGiant ? 8 : 14),
      ),
    );

    final content = isGiant
        ? field
        : Container(
            decoration: BoxDecoration(
              color: LdColors.backgroundElevated,
              borderRadius: LdRadii.fieldRadius,
              border: Border.all(
                color: widget.errorText != null
                    ? LdColors.accentWarning
                    : _focused
                        ? LdColors.accentPrimary
                        : LdColors.strokeOutline,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: <Widget>[
                if (widget.prefixGlyph != null) ...<Widget>[
                  LdIcon(
                    widget.prefixGlyph!,
                    size: 18,
                    color: LdColors.foregroundSecondary,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(child: field),
                if (widget.obscure)
                  LdTappable(
                    onTap: () => setState(() => _revealed = !_revealed),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: LdIcon(
                        _revealed ? LdGlyph.eyeOff : LdGlyph.eye,
                        size: 18,
                        color: LdColors.foregroundSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(widget.label!, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
        ],
        content,
        if (widget.errorText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall!
                .copyWith(color: LdColors.accentWarning),
          ),
        ] else if (widget.helperText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(widget.helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// The search field, its own shape because it appears in a toolbar rather
/// than a form.
class LdSearchField extends StatelessWidget {
  const LdSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: LdColors.backgroundElevated,
        borderRadius: LdRadii.pillRadius,
        border: Border.all(color: LdColors.strokeOutline),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          const LdIcon(
            LdGlyph.search,
            size: 18,
            color: LdColors.foregroundSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyLarge,
              cursorColor: LdColors.accentPrimary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: Theme.of(context).textTheme.bodyMedium,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return LdTappable(
                onTap: () {
                  controller.clear();
                  onChanged?.call('');
                },
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: LdIcon(
                    LdGlyph.close,
                    size: 16,
                    color: LdColors.foregroundSecondary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
