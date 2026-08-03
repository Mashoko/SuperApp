import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/dialpad/presentation/widgets/dialer_gradient_background.dart';

void main() {
  testWidgets('DialerGradientBackground paints the gradient and shows its child',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DialerGradientBackground(
          child: Center(child: Text('inner content')),
        ),
      ),
    );

    expect(find.text('inner content'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.decoration, isA<BoxDecoration>());
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
  });

  testWidgets('GlassPanelContainer renders rounded translucent panel with its child',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassPanelContainer(
          child: Center(child: Text('panel content')),
        ),
      ),
    );

    expect(find.text('panel content'), findsOneWidget);
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(32));
  });
}
