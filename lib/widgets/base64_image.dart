import 'dart:convert';

import 'package:flutter/material.dart';

class Base64Image extends StatelessWidget {
  const Base64Image({
    super.key,
    required this.data,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.live = false,
  });

  final String data;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool live;

  @override
  Widget build(BuildContext context) {
    try {
      var raw = data;
      if (raw.contains(',')) raw = raw.split(',').last;
      final bytes = base64Decode(raw);
      final image = Image.memory(
        bytes,
        key: live ? ValueKey(raw.length ^ raw.hashCode) : null,
        fit: fit,
        gaplessPlayback: !live,
        filterQuality: live ? FilterQuality.low : FilterQuality.medium,
      );
      if (borderRadius != null) {
        return ClipRRect(borderRadius: borderRadius!, child: image);
      }
      return image;
    } catch (_) {
      return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38));
    }
  }
}