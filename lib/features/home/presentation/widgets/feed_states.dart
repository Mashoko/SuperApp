import 'package:flutter/material.dart';

class FeedLoadingSkeleton extends StatelessWidget {
  const FeedLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 160,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class FeedErrorState extends StatelessWidget {
  const FeedErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class FeedEmptyState extends StatelessWidget {
  const FeedEmptyState({super.key, required this.onCompose});

  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text('No posts yet — be the first to share',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: onCompose, child: const Text('Share something')),
        ],
      ),
    );
  }
}

class FeedLoadMoreRetry extends StatelessWidget {
  const FeedLoadMoreRetry({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(onPressed: onRetry, child: const Text('Load more failed — retry')),
      ),
    );
  }
}
