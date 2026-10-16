import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';

/// Small coloured label for Flutter / Android / iOS.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.slug, required this.name});
  final String slug;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.category(slug);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(name.toUpperCase(), style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 5)],
        Text(text, style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Coloured square with the company's first letter (no third-party logos needed).
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.name, this.size = 46});
  final String name;
  final double size;
  static const _colors = [Color(0xFF0F6B56), Color(0xFF2F6FD6), Color(0xFFC0571B), Color(0xFF7B4FD6), Color(0xFFB8860B), Color(0xFF0277BD), Color(0xFFC2185B), Color(0xFF2E7D32)];

  @override
  Widget build(BuildContext context) {
    final i = name.codeUnits.fold<int>(0, (a, c) => a + c) % _colors.length;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _colors[i], borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.42)),
    );
  }
}

/// Round avatar: network or data-URL photo, else initials.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.photo, this.size = 96});
  final String name;
  final String? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.soft,
      child: Text(Fmt.initials(name), style: TextStyle(fontSize: size * 0.34, fontWeight: FontWeight.w800, color: AppColors.green)),
    );
    final p = photo;
    if (p == null || p.isEmpty) return fallback;
    final ImageProvider img = p.startsWith('data:image/')
        ? MemoryImage(UriData.parse(p).contentAsBytes())
        : CachedNetworkImageProvider(p);
    return CircleAvatar(radius: size / 2, backgroundImage: img, onBackgroundImageError: (_, __) {});
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );
}

void showMessage(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {})));
}
