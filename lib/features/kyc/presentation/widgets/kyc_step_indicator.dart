import 'package:flutter/material.dart';

const kycStepLabels = ['Personal', 'Address', 'ID details', 'Documents', 'Review'];

/// Five hairline segments with the current step named. Wide layouts label
/// every segment; narrow ones name only the current step.
class KycStepIndicator extends StatelessWidget {
  const KycStepIndicator({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = kycStepLabels.length;

    Widget segment(int i) => Container(
          height: 4,
          decoration: BoxDecoration(
            color: i <= step ? scheme.primary : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    return Semantics(
      label: 'Step ${step + 1} of $total: ${kycStepLabels[step]}',
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      segment(i),
                      const SizedBox(height: 8),
                      Text(
                        kycStepLabels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: i == step ? FontWeight.w600 : FontWeight.w400,
                          color: i == step ? scheme.onSurface : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(child: segment(i)),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Flexible(
                child: Text(
                  kycStepLabels[step],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Step ${step + 1} of $total',
                style: text.bodyLarge
                    ?.copyWith(fontSize: 16, color: scheme.onSurfaceVariant),
              ),
            ]),
          ],
        );
      }),
    );
  }
}
