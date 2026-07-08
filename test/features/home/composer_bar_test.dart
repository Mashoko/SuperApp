import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/composer_bar.dart';
import 'package:mvvm_sip_demo/features/home/presentation/widgets/composer_choice_sheet.dart';
import 'package:mvvm_sip_demo/models/post.dart';

void main() {
  testWidgets('ComposerBar shows the placeholder text and initials, and invokes onTap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ComposerBar(userInitials: 'AB', onTap: () => tapped = true),
      ),
    ));

    expect(find.text('Share something...'), findsOneWidget);
    expect(find.text('AB'), findsOneWidget);

    await tester.tap(find.byType(ComposerBar));
    expect(tapped, true);
  });

  testWidgets('ComposerChoiceSheet shows all 4 options and reports the chosen type',
      (tester) async {
    PostType? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ComposerChoiceSheet.show(context, (type) => chosen = type),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(chosen, PostType.video);
  });
}
