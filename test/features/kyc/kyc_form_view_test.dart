import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/features/kyc/data/kyc_service.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_view.dart';
import 'package:mvvm_sip_demo/features/kyc/presentation/kyc_form_viewmodel.dart';

import 'kyc_test_fakes.dart';

const _stepLabels = ['Personal', 'Address', 'ID details', 'Documents', 'Review'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeKycService service;
  late FakeKycController controller;
  late KycFormViewModel vm;

  setUp(() {
    service = FakeKycService();
    controller = FakeKycController(kycStatus(
      draft: completeDraft,
      documents: [docJson('id_front'), docJson('id_back', mime: 'application/pdf')],
    ));
    vm = KycFormViewModel(service, controller);
  });

  tearDown(() {
    vm.dispose();
    controller.dispose();
  });

  Future<void> pumpForm(WidgetTester tester,
      {Size size = const Size(375, 800), ThemeData? theme}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: theme ?? ThemeData(useMaterial3: true),
      home: KycFormView(viewModel: vm),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  TextField field(WidgetTester tester, String label) =>
      tester.widget<TextField>(find.widgetWithText(TextField, label));

  testWidgets('step 0 shows title, intro, phone read-only and labelled fields',
      (tester) async {
    await pumpForm(tester);
    expect(find.text('Verify your number'), findsOneWidget);
    expect(
        find.text(
            'POTRAZ requires us to confirm who owns each number. It takes about 5 minutes.'),
        findsOneWidget);
    expect(find.text('263771234567'), findsOneWidget);
    expect(find.widgetWithText(TextField, '263771234567'), findsNothing,
        reason: 'phone is never an editable field');
    expect(field(tester, 'First name').keyboardType, TextInputType.name);
    expect(field(tester, 'Last name').keyboardType, TextInputType.name);
    expect(field(tester, 'First name').style?.fontSize, greaterThanOrEqualTo(16));
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('4 May 1990'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Nationality'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('walks every step with labels and keyboards', (tester) async {
    await pumpForm(tester);
    Future<void> next() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
    }

    await next();
    expect(vm.step, 1);
    expect(field(tester, 'Address').keyboardType, TextInputType.streetAddress);
    expect(find.widgetWithText(TextField, 'Address line 2 (optional)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'City or town'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Country'), findsOneWidget);

    await next();
    expect(vm.step, 2);
    expect(find.text('ID type'), findsOneWidget);
    final id = field(tester, 'ID number');
    expect(id.controller?.text, isEmpty);
    expect(id.decoration?.hintText, '*********A42');

    await next();
    expect(vm.step, 3);
    expect(find.text('National ID, front'), findsOneWidget);
    expect(find.text('National ID, back'), findsOneWidget);
    expect(find.text('Passport photo page'), findsNothing);
    expect(find.text('Proof of residence'), findsNothing);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);

    await next();
    expect(vm.step, 4);
    expect(find.text('Check your details'), findsOneWidget);
    expect(find.text('Tendai'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Submit for review'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget,
        reason: 'submit is the single primary button');
    await finish(tester);
  });

  testWidgets('blocked next shows field errors', (tester) async {
    controller.status = kycStatus();
    await pumpForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(vm.step, 0);
    expect(find.text('Enter your first name.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('empty document tile and upload error copy', (tester) async {
    controller.status = kycStatus(draft: completeDraft);
    await pumpForm(tester);
    vm.goToStep(3);
    await tester.pumpAndSettle();
    expect(find.text('Add photo or file'), findsNWidgets(2));
    service.uploadError = KycApiException(0, 'No connection.');
    await vm.upload('id_front', KycPickedFile(bytes: Uint8List(4), filename: 'a.jpg'));
    await tester.pumpAndSettle();
    expect(find.text('Upload failed. Tap to retry.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('save state copy', (tester) async {
    await pumpForm(tester);
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Rudo');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    service.saveError = KycApiException(0, 'offline');
    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Rudo M');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Not saved. Check your connection.'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('success copy after submit', (tester) async {
    await pumpForm(tester);
    vm.goToStep(4);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit for review'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Thanks. We are reviewing your details. You can keep using the app while we check.'),
        findsOneWidget);
    expect(controller.refreshCalls, 1);
    await finish(tester);
  });

  testWidgets('load error offers retry', (tester) async {
    controller.status = null;
    controller.failWith = 'No connection. Check your internet and try again.';
    await pumpForm(tester);
    expect(find.text('No connection. Check your internet and try again.'),
        findsOneWidget);
    controller.failWith = null;
    controller.next = kycStatus(draft: completeDraft);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your number'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'First name'), findsOneWidget);
    await finish(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('tap targets, labels and contrast on every step'
        '${dark ? ' (dark)' : ''}', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpForm(tester,
          theme: ThemeData(
              useMaterial3: true,
              brightness: dark ? Brightness.dark : Brightness.light));
      for (var s = 0; s < 5; s++) {
        vm.goToStep(s);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
            reason: 'step $s');
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
            reason: 'step $s');
        await expectLater(tester, meetsGuideline(textContrastGuideline),
            reason: 'step $s');
      }
      handle.dispose();
      await finish(tester);
    });
  }

  for (final size in const [Size(375, 800), Size(768, 1024), Size(1280, 800)]) {
    for (final dark in [false, true]) {
      testWidgets(
          'no overflow on any step at ${size.width.toInt()}x${size.height.toInt()}'
          '${dark ? ' (dark)' : ''}', (tester) async {
        controller.status = kycStatus(
          draft: completeDraft,
          outstanding: ['documents.proof_of_residence'],
          documents: [docJson('id_front')],
        );
        await pumpForm(tester,
            size: size,
            theme: ThemeData(
                useMaterial3: true,
                brightness: dark ? Brightness.dark : Brightness.light));
        for (var s = 0; s < 5; s++) {
          vm.goToStep(s);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'step $s');
          expect(find.text(_stepLabels[s]), findsWidgets);
        }
        await finish(tester);
      });
    }
  }
}
