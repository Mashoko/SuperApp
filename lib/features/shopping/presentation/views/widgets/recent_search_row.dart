import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/core/theme.dart';

class RecentSearchRow extends StatelessWidget {
  final List<String> recentSearches;
  final Function(String) onSearchTap;

  const RecentSearchRow({
    super.key,
    required this.recentSearches,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Recent Search',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: recentSearches.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return ActionChip(
                label: Text(recentSearches[index]),
                backgroundColor: WunzaColors.surface,
                side: const BorderSide(color: WunzaColors.divider),
                onPressed: () => onSearchTap(recentSearches[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
