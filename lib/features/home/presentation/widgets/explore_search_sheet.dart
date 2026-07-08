import 'package:flutter/material.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/explore_models.dart';

/// Full-screen search takeover opened from the Explore tab's sticky search
/// bar. Everything here runs against static placeholder data — see the
/// Explore discovery hub design spec's non-goals for why there's no real
/// search backend yet.
class ExploreSearchSheet extends StatefulWidget {
  const ExploreSearchSheet({super.key});

  @override
  State<ExploreSearchSheet> createState() => _ExploreSearchSheetState();
}

class _ExploreSearchSheetState extends State<ExploreSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<String> _recent = List.of(recentSearches);
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<DiscoveryItem> get _suggestions {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return allDiscoveryItems
        .where((i) => i.title.toLowerCase().contains(q))
        .toList();
  }

  void _selectSuggestion(String title) {
    _controller.text = title;
    Navigator.pop(context);
  }

  void _removeRecent(String value) {
    setState(() => _recent.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search products, businesses, events, services, people...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_query.isNotEmpty) ...[
            Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (_suggestions.isEmpty)
              Text('No matches', style: Theme.of(context).textTheme.bodySmall)
            else
              for (final item in _suggestions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.search),
                  title: Text(item.title),
                  subtitle: Text(item.subtitle),
                  onTap: () => _selectSuggestion(item.title),
                ),
          ] else ...[
            if (_recent.isNotEmpty) ...[
              Text('Recent searches',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              for (final term in _recent)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(term),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeRecent(term),
                  ),
                  onTap: () => _selectSuggestion(term),
                ),
              const SizedBox(height: 18),
            ],
            Text('Trending searches',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in trendingSearches)
                  ActionChip(
                    avatar: const Icon(Icons.trending_up, size: 16),
                    label: Text(term),
                    onPressed: () => _selectSuggestion(term),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Browse by category',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in exploreCategories)
                  ActionChip(
                    avatar: Icon(category.icon, size: 16),
                    label: Text(category.label),
                    onPressed: () => _selectSuggestion(category.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
