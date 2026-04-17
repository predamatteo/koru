import 'package:flutter/material.dart';

import '../../../../core/constants/koru_colors.dart';

class PlaceholderTabBody extends StatelessWidget {
  const PlaceholderTabBody({
    required this.icon,
    required this.label,
    required this.hint,
    super.key,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: KoruColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KoruColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
