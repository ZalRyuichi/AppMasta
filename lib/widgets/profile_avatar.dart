import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.size = 56,
    this.fontSize,
    this.borderColor,
    this.borderWidth = 3,
    this.accentColor,
  });

  final String name;
  final String? imagePath;
  final double size;
  final double? fontSize;
  final Color? borderColor;
  final double borderWidth;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final ring = borderColor ?? AppColors.neoBlack;
    final fill = accentColor ?? AppColors.dashAccent;
    final hasImage = imagePath != null && File(imagePath!).existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: borderWidth),
        boxShadow: NeoShadow.hard(dx: 3, dy: 3),
        color: hasImage ? null : fill,
      ),
      child: ClipOval(
        child: hasImage
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _Initial(initial: initial, size: size, fontSize: fontSize, color: Colors.white),
              )
            : _Initial(initial: initial, size: size, fontSize: fontSize, color: Colors.white),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial, required this.size, this.fontSize, required this.color});

  final String initial;
  final double size;
  final double? fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.dashAccent,
      child: Center(
        child: Text(
          initial,
          style: AppTypography.statValue(active: true).copyWith(
            fontSize: fontSize ?? size * 0.38,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
