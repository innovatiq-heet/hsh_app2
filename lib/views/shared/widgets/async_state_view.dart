import 'package:flutter/material.dart';
import 'empty_state.dart';
import 'skeleton_loader.dart';

/// Standard loading / error / content switcher, paired with
/// [LoadStateMixin] on the controller side. Replaces the repeated
/// `if (isLoading) return SkeletonList(); ...` branch that used to be
/// copy-pasted into every screen.
class AsyncStateView extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final VoidCallback onRetry;
  final WidgetBuilder builder;
  final int skeletonCount;

  const AsyncStateView({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onRetry,
    required this.builder,
    this.skeletonCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (isLoading) {
      child = SkeletonList(
        key: const ValueKey<String>('async_loading'),
        count: skeletonCount,
      );
    } else if (hasError) {
      child = EmptyState(
        key: const ValueKey<String>('async_error'),
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: errorMessage.isEmpty ? null : errorMessage,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    } else {
      child = KeyedSubtree(
        key: const ValueKey<String>('async_content'),
        child: builder(context),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }
}
