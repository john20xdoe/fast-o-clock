import 'package:flutter/material.dart';

class AppBrandTitle extends StatelessWidget {
  const AppBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Fast O'Clock",
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontVariations: const [FontVariation.weight(800)],
          ),
        ),
        Text(
          'your time to fast',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
