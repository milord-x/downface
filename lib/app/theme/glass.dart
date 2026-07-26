import 'dart:ui';
import 'package:flutter/cupertino.dart';

class AppColors {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const surfaceRaised = Color(0xFF1C1C1E);
  static const stroke = Color(0x33FFFFFF);
  static const white = Color(0xFFFFFFFF);
  static const dim = Color(0xFF8E8E93);
  static const faint = Color(0xFF48484A);
}

class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
    this.tint = AppColors.surface,
    this.tintOpacity = 0.55,
    this.blur = 24,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double tintOpacity;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: tintOpacity),
            borderRadius: radius,
            border: Border.all(color: AppColors.stroke, width: 0.8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 26,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
    this.filled = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: filled
          ? Container(
              padding: padding,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: child,
            )
          : LiquidGlass(
              borderRadius: borderRadius,
              padding: padding,
              child: child,
            ),
    );
  }
}
