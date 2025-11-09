import 'package:flutter/material.dart';
import 'package:airlink/core/services/haptic_service.dart';

/// A responsive button widget that provides immediate visual and haptic feedback
class ResponsiveButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final bool isOutlined;
  final bool isElevated;
  final IconData? icon;
  final double? elevation;
  final Size? minimumSize;
  final bool enableHaptic;

  const ResponsiveButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
    this.isOutlined = false,
    this.isElevated = false,
    this.icon,
    this.elevation,
    this.minimumSize,
    this.enableHaptic = true,
  });

  @override
  State<ResponsiveButton> createState() => _ResponsiveButtonState();
}

class _ResponsiveButtonState extends State<ResponsiveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final HapticService _haptic = HapticService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onPressed == null) return;

    // Immediate visual feedback
    _controller.forward().then((_) => _controller.reverse());

    // Immediate haptic feedback
    if (widget.enableHaptic) {
      await _haptic.light();
    }

    // Execute the callback
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.icon != null
          ? _buildIconButton(context)
          : _buildButton(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    if (widget.isOutlined) {
      return OutlinedButton(
        onPressed: widget.onPressed != null ? _handleTap : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          minimumSize: widget.minimumSize,
        ),
        child: widget.child,
      );
    } else if (widget.isElevated) {
      return ElevatedButton(
        onPressed: widget.onPressed != null ? _handleTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          elevation: widget.elevation ?? 2,
          minimumSize: widget.minimumSize,
        ),
        child: widget.child,
      );
    } else {
      return FilledButton(
        onPressed: widget.onPressed != null ? _handleTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          minimumSize: widget.minimumSize,
        ),
        child: widget.child,
      );
    }
  }

  Widget _buildIconButton(BuildContext context) {
    if (widget.isOutlined) {
      return OutlinedButton.icon(
        onPressed: widget.onPressed != null ? _handleTap : null,
        icon: Icon(widget.icon),
        label: widget.child,
        style: OutlinedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          minimumSize: widget.minimumSize,
        ),
      );
    } else if (widget.isElevated) {
      return ElevatedButton.icon(
        onPressed: widget.onPressed != null ? _handleTap : null,
        icon: Icon(widget.icon),
        label: widget.child,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          elevation: widget.elevation ?? 2,
          minimumSize: widget.minimumSize,
        ),
      );
    } else {
      return FilledButton.icon(
        onPressed: widget.onPressed != null ? _handleTap : null,
        icon: Icon(widget.icon),
        label: widget.child,
        style: FilledButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          minimumSize: widget.minimumSize,
        ),
      );
    }
  }
}

/// A responsive icon button with haptic feedback
class ResponsiveIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? size;
  final String? tooltip;
  final bool enableHaptic;

  const ResponsiveIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size,
    this.tooltip,
    this.enableHaptic = true,
  });

  @override
  State<ResponsiveIconButton> createState() => _ResponsiveIconButtonState();
}

class _ResponsiveIconButtonState extends State<ResponsiveIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final HapticService _haptic = HapticService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onPressed == null) return;

    // Immediate visual feedback
    _controller.forward().then((_) => _controller.reverse());

    // Immediate haptic feedback
    if (widget.enableHaptic) {
      await _haptic.light();
    }

    // Execute the callback
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(widget.icon),
        onPressed: widget.onPressed != null ? _handleTap : null,
        color: widget.color,
        iconSize: widget.size,
        tooltip: widget.tooltip,
      ),
    );
  }
}

