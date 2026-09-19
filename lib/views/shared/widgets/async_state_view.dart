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
    if (isLoading) return SkeletonList(count: skeletonCount);
    if (hasError) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: errorMessage.isEmpty ? null : errorMessage,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }
    return builder(context);
  }
}
