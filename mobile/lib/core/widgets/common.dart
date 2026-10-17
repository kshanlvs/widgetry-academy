import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/theme/app_theme.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';

/// The Widgetry mark: four rounded squares, as on the website.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final cell = size * 0.42;
    final gap = size - cell * 2;
    final last = onDark ? Colors.white : AppColors.deep;
    Widget sq(Color c) => Container(width: cell, height: cell, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(cell * 0.3)));
    return SizedBox(
      width: size,
      height: size,
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [sq(AppColors.gold), SizedBox(width: gap), sq(AppColors.greenBright)]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [sq(AppColors.greenBright), SizedBox(width: gap), sq(last)]),
      ]),
    );
  }
}

/// "Widgetry" wordmark with the mark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.suffix, this.onDark = false, this.size = 18});
  final String? suffix;
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ink = onDark ? Colors.white : p.ink;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(size: size * 1.25, onDark: onDark),
      SizedBox(width: size * 0.55),
      Text('Widgetry', style: AppTheme.display(size: size, color: ink, weight: FontWeight.w700)),
      if (suffix != null) Text(' $suffix', style: AppTheme.display(size: size, color: onDark ? AppColors.gold : p.accent, weight: FontWeight.w500)),
    ]);
  }
}

/// Small category label: coloured dot + name (Flutter / Android / iOS).
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.slug, required this.name});
  final String slug;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.category(slug);
    final p = Palette.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(name, style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Quiet rounded label. [tone] colours it (e.g. green for "Open to work").
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = color ?? p.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color == null ? p.soft.withValues(alpha: 0.6) : c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: color == null ? p.ink.withValues(alpha: 0.78) : c, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2)),
      ]),
    );
  }
}

/// Company initial on a soft tinted tile (no third-party logos needed).
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.name, this.size = 46});
  final String name;
  final double size;
  static const _tints = [Color(0xFF0F6B56), Color(0xFF2B5FB8), Color(0xFFB2551F), Color(0xFF6A4BC4), Color(0xFF8C6A0A), Color(0xFF0B6F8F), Color(0xFFAD2D5C), Color(0xFF3B6B2A)];

  @override
  Widget build(BuildContext context) {
    final i = name.codeUnits.fold<int>(0, (a, c) => a + c) % _tints.length;
    final c = _tints[i];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: dark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: c.withValues(alpha: dark ? 0.30 : 0.16)),
      ),
      child: Text(
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        style: AppTheme.display(size: size * 0.40, color: dark ? Color.lerp(c, Colors.white, 0.45) : c, weight: FontWeight.w600, height: 1),
      ),
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
    final p = Palette.of(context);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.soft, shape: BoxShape.circle),
      child: Text(Fmt.initials(name), style: AppTheme.display(size: size * 0.32, color: p.accent, weight: FontWeight.w600, height: 1)),
    );
    final ph = photo;
    if (ph == null || ph.isEmpty) return fallback;
    final ImageProvider img = ph.startsWith('data:image/') ? MemoryImage(UriData.parse(ph).contentAsBytes()) : CachedNetworkImageProvider(ph);
    return ClipOval(child: Image(image: img, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback));
  }
}

/// Small uppercase label above a group of content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(Space.page, Space.xxl, Space.page, Space.sm)});
  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
          if (trailing != null) trailing!,
        ]),
      );
}

/// A titled block inside a bordered surface.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: Space.md),
            child,
          ]),
        ),
      );
}

/// Rows grouped in one bordered surface, separated by hairlines (settings-style lists).
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.margin = const EdgeInsets.symmetric(horizontal: Space.lg)});
  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) Divider(indent: Space.lg, color: p.line),
          c,
        ],
      ]),
    );
  }
}

/// Label/value pair, used in fact grids (Location, Experience, Salary…).
class Fact extends StatelessWidget {
  const Fact({super.key, required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (icon != null) ...[Icon(icon, size: 18, color: p.faint), const SizedBox(width: 10)],
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.bodySmall?.copyWith(color: p.faint)),
          const SizedBox(height: 2),
          Text(value, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      ),
    ]);
  }
}

/// Sticky action area at the bottom of detail screens, above the system bar.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.leading});
  final Widget child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: Space.md)],
            Expanded(child: child),
          ]),
        ),
      ),
    );
  }
}

/// Button content that swaps to a small spinner while busy, keeping the button's size.
class BusyLabel extends StatelessWidget {
  const BusyLabel({super.key, required this.busy, required this.label});
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: busy
            ? SizedBox(key: const ValueKey('b'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: DefaultTextStyle.of(context).style.color))
            : Text(label, key: const ValueKey('l')),
      );
}

/// Light haptic tick for selections (tabs, chips, save).
void tick() => HapticFeedback.selectionClick();

void showMessage(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {})));
}
