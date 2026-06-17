import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A square cover card with a title + subtitle beneath.
/// Used in horizontal rails on the Home screen.
class CoverCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final double size;
  final bool circular;
  final VoidCallback? onTap;

  const CoverCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.size = 150,
    this.circular = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = circular ? size / 2 : 8.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: AppColors.surface,
                image: DecorationImage(
                  image: CachedNetworkImageProvider(
                    imageUrl,
                    maxWidth: size.toInt(),
                    maxHeight: size.toInt(),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: imageUrl.isEmpty
                  ? Icon(Icons.music_note, color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}