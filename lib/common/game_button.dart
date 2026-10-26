import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resource/app_colors.dart';

/// [raised] is a lighter surface for blocks that sit on a surface card.
enum GameTone { primary, accent, surface, raised }

extension on GameTone {
  Color get face => switch (this) {
    GameTone.primary => AppColors.primary,
    GameTone.accent => AppColors.accent,
    GameTone.surface => AppColors.surface,
    GameTone.raised => AppColors.surfaceRaised,
  };

  Color get depth => switch (this) {
    GameTone.primary => AppColors.primaryDepth,
    GameTone.accent => AppColors.accentDepth,
    GameTone.surface || GameTone.raised => AppColors.surfaceDepth,
  };

  bool get isSurface => this == GameTone.surface || this == GameTone.raised;
}

/// Chunky block with a darker bottom edge. When [onTap] is set it presses
/// down into its edge, with a light haptic, like a game button.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.child,
    this.onTap,
    this.tone = GameTone.surface,
    this.selected = false,
    this.radius = 20,
    this.depth = 5,
    this.padding,
    this.tooltip,
    this.fadeWhenDisabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GameTone tone;

  /// Draws a thick primary outline, for the chosen tile in a group.
  final bool selected;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;

  /// Coloured tones fade without [onTap], reading as a disabled button. Set
  /// false for static blocks such as hero cards and the brand tile.
  final bool fadeWhenDisabled;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final depth = widget.depth.h;
    final radius = BorderRadius.circular(widget.radius.r);
    final enabled = widget.onTap != null;
    final face = widget.selected ? AppColors.surfaceRaised : widget.tone.face;
    final edge = widget.selected ? AppColors.primaryDepth : widget.tone.depth;

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      margin: EdgeInsets.only(top: _pressed ? depth : 0),
      padding: EdgeInsets.only(bottom: _pressed ? 0 : depth),
      decoration: BoxDecoration(color: edge, borderRadius: radius),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: face,
          borderRadius: radius,
          border: widget.selected
              ? Border.all(color: AppColors.primary, width: 2.5.r)
              : widget.tone.isSurface
              ? Border.all(color: AppColors.border, width: 1.r)
              : null,
        ),
        child: widget.child,
      ),
    );

    if (enabled) {
      button = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap!();
        },
        child: button,
      );
    } else if (widget.fadeWhenDisabled && !widget.tone.isSurface) {
      button = Opacity(opacity: 0.45, child: button);
    }
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return Semantics(button: enabled, child: button);
  }
}

/// Square icon-only [GameButton], e.g. header and toolbar actions.
class GameIconButton extends StatelessWidget {
  const GameIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.tone = GameTone.surface,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final GameTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GameButton(
      tone: tone,
      onTap: onTap,
      tooltip: tooltip,
      radius: 14,
      depth: 4,
      child: SizedBox.square(
        dimension: size.r,
        child: Icon(
          icon,
          size: (size * 0.48).r,
          color: tone == GameTone.accent ? AppColors.onAccent : AppColors.textPrimary,
        ),
      ),
    );
  }
}
