import 'package:flutter/material.dart';
import '../../shared/widgets/navy_sliver_header.dart';

/// Pinned navy header for the Screen Time sub-screens (usage, apps, ...): the
/// shared [NavySliverHeader] with a back button.
class ScreenTimeSubHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const ScreenTimeSubHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => NavySliverHeader(title: title, subtitle: subtitle, onBack: onBack);
}
