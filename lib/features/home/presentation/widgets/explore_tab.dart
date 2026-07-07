import 'package:flutter/material.dart';

/// Placeholder discovery hub for the Explore tab. Content is static —
/// there's no backing data source yet (see the glass-bottom-nav design
/// spec's "Open items deferred" section). This is a structural port of
/// the GlassNav.jsx mockup's ExplorePage, not a new data feature.
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  static const _categories = ['All', 'Trending', 'Nearby', 'New', 'Events'];
  String _selected = 'All';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
      children: [
        Row(
          children: [
            Icon(Icons.explore_outlined,
                color: Theme.of(context).colorScheme.secondary),
            const SizedBox(width: 8),
            Text('Explore', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = _categories[i];
              final selected = c == _selected;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _selected = c),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Trending now',
          icon: Icons.local_fire_department_outlined,
          items: const ['Wireless earbuds', 'Desk lamp', 'Running shoes'],
        ),
        _Section(
          title: 'Recommended for you',
          icon: Icons.auto_awesome_outlined,
          items: const [
            'Weekend picks',
            'Based on your shop history',
            'Similar to your saves',
          ],
        ),
        _RowSection(
          title: 'Nearby offers',
          icon: Icons.place_outlined,
          rows: const [
            ('Corner Cafe', '20% off, 0.3 mi away'),
            ('Green Market', 'Fresh produce, 0.8 mi away'),
          ],
        ),
        _RowSection(
          title: 'Recently added',
          icon: Icons.access_time_outlined,
          rows: const [
            ('New: Split payments', 'Send money together with friends'),
            ('New: Local events', 'Discover things happening near you'),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Theme.of(context).hintColor),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _MediaCard(title: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color:
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _RowSection extends StatelessWidget {
  const _RowSection(
      {required this.title, required this.icon, required this.rows});

  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Theme.of(context).hintColor),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          for (final (name, sub) in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context).textTheme.bodyLarge),
                        Text(sub,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
