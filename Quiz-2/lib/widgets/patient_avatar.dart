import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PatientAvatar extends StatelessWidget {
  final String name;
  final String? imagePath;
  final double size;

  const PatientAvatar({
    super.key,
    required this.name,
    this.imagePath,
    this.size = 56,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && File(imagePath!).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.gradient,
        border: Border.all(color: Colors.white, width: size > 80 ? 4 : 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        image: hasImage
            ? DecorationImage(
                image: FileImage(File(imagePath!)), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
