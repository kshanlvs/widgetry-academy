import 'package:flutter/material.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';

/// Loading, error and empty states used by every screen, so they look and behave the same.
/// Lists use [SkeletonList] (content-shaped placeholders) instead of a spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)),
          if (message != null) ...[const SizedBox(height: 14), Text(message!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Palette.of(context).muted))],
        ]),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry, this.title = "Couldn't load this"});
  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => _StateBody(
        icon: Icons.wifi_off_rounded,
        title: title,
        message: message,
        action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _StateBody(icon: icon, title: title, message: message, action: action);
}

class _StateBody extends StatelessWidget {
  const _StateBody({required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Icon(icon, size: 26, color: p.accent),
            ),
            const SizedBox(height: Space.lg),
            Text(title, textAlign: TextAlign.center, style: t.titleMedium),
            if (message != null) ...[const SizedBox(height: 6), Text(message!, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: p.muted))],
            if (action != null) ...[const SizedBox(height: Space.xl), action!],
          ]),
        ),
      ),
    );
  }
}

/// Soft pulsing placeholder block. Wrap several in [Shimmer] to animate them together.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Palette.of(context).soft, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Fades its child in and out gently while content loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
}

/// List-shaped placeholder: logo square + three lines per row.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.leading = true, this.padding = const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg)});
  final int count;
  final bool leading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: Space.md),
        itemBuilder: (_, i) => Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: p.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (leading) ...[const SkeletonBox(width: 44, height: 44, radius: 12), const SizedBox(width: Space.md)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonBox(width: i.isEven ? 210 : 170, height: 14),
                const SizedBox(height: 10),
                const SkeletonBox(width: 120),
                const SizedBox(height: 14),
                SkeletonBox(width: i.isEven ? 160 : 190, height: 10),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Sliver version of [SkeletonList] for CustomScrollView screens.
class SliverSkeletonList extends StatelessWidget {
  const SliverSkeletonList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) => SliverFillRemaining(hasScrollBody: true, child: SkeletonList(count: count));
}
