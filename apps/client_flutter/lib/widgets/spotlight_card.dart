import 'package:flutter/material.dart';

class SpotlightCard extends StatelessWidget {
  const SpotlightCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
