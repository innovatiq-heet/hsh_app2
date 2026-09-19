import 'package:flutter/material.dart';
import 'empty_state.dart';
import 'skeleton_loader.dart';

/// Standard loading / error / content switcher, paired with
/// [LoadStateMixin] on the controller side. Cross-fades between the three
/// states so skeleton → content never hard-cuts.
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final VoidCallback onRetry;
  final WidgetBuilder builder;
  final int skeletonCount;

  /// Placeholder shown while loading; defaults to a [SkeletonList]. Hero
  /// screens pass a [HeroSkeleton] so the layout matches.
  final Widget? skeleton;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onRetry,
    required this.builder,
    this.skeletonCount = 5,
    this.skeleton,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (isLoading) {
      child = KeyedSubtree(
        key: const ValueKey('loading'),
        child: skeleton ?? SkeletonList(count: skeletonCount),
      );
    } else if (hasError) {
      child = KeyedSubtree(
        key: const ValueKey('error'),
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Something went wrong',
          message: errorMessage.isEmpty ? null : errorMessage,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      );
    } else {
      child = KeyedSubtree(
        key: const ValueKey('content'),
        child: builder(context),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}
