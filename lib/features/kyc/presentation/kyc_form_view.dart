import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/di/inject.dart';
import '../data/kyc_service.dart';
import 'kyc_form_viewmodel.dart';
import 'kyc_labels.dart';
import 'kyc_status_controller.dart';
import 'kyc_theme.dart';
import 'widgets/kyc_document_tile.dart';
import 'widgets/kyc_step_indicator.dart';

final _dateFormat = DateFormat('d MMMM y');

/// Dates in the form are date-only (UTC midnight). Formatting reads the
/// calendar fields directly, so no time zone conversion happens.
String _formatDate(DateTime? d) => d == null ? '' : _dateFormat.format(d);

/// Multi-step KYC form. Uses only `Navigator.of(context)` so it also works
/// inside a nested navigator. Pops with `true` after a successful submit.
class KycFormView extends StatefulWidget {
  const KycFormView({super.key, this.viewModel});

  /// For tests. When null the view builds its own from get_it and disposes it.
  final KycFormViewModel? viewModel;

  @override
  State<KycFormView> createState() => _KycFormViewState();
}

class _KycFormViewState extends State<KycFormView> {
  late final KycFormViewModel _vm;
  late final bool _ownsVm;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    _vm = widget.viewModel ??
        KycFormViewModel(getIt<KycService>(), getIt<KycStatusController>());
    if (_vm.loading) unawaited(_vm.load());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  TextEditingController _controller(String key, String? initial) => _controllers
      .putIfAbsent(key, () => TextEditingController(text: initial ?? ''));

  @override
  Widget build(BuildContext context) {
    final theme = kycTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          final scheme = theme.colorScheme;
          final inSteps = !_vm.loading &&
              _vm.loadError == null &&
              !_vm.readOnly &&
              !_vm.submitted;
          // System back walks back through the steps; on the first step (and
          // in every non-form state) it leaves the screen as usual.
          return PopScope(
            canPop: !inSteps || _vm.step == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && inSteps) _vm.back();
            },
            child: Scaffold(
              backgroundColor: scheme.surface,
              appBar: AppBar(title: const Text('Verify your number')),
              body: _body(context),
              bottomNavigationBar: inSteps ? _bottomBar(context) : null,
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vm.loadError != null) {
      return KycMessage(
        icon: Icons.cloud_off_outlined,
        text: _vm.loadError!,
        action: FilledButton(
          onPressed: () => unawaited(_vm.load()),
          child: const Text('Try again'),
        ),
      );
    }
    if (_vm.readOnly) {
      return KycMessage(
        icon: Icons.check_circle_outline,
        title: 'Your details are with us',
        text: _vm.lockedStatus == 'APPROVED'
            ? 'You are verified. Thank you.'
            : 'We are reviewing your details. '
                'You can keep using the app while we check.',
        action: FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Done'),
        ),
      );
    }
    if (_vm.submitted) {
      return KycMessage(
        icon: Icons.check_circle_outline,
        text: 'Thanks. We are reviewing your details. '
            'You can keep using the app while we check.',
        action: FilledButton(
          onPressed: () => Navigator.of(context).maybePop(true),
          child: const Text('Done'),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        KycConstrained(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_vm.staleNotice != null) ...[
                KycNotice(text: _vm.staleNotice!),
                const SizedBox(height: 12),
              ],
              KycStepIndicator(step: _vm.step),
              _SaveStatus(vm: _vm),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey('kyc-step-${_vm.step}'),
            child: KycConstrained(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: _stepContent(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepContent(BuildContext context) {
    switch (_vm.step) {
      case 0:
        return _personalStep(context);
      case 1:
        return _addressStep(context);
      case 2:
        return _idStep(context);
      case 3:
        return _documentsStep(context);
      default:
        return _reviewStep(context);
    }
  }

  // --- Steps ----------------------------------------------------------------

  Widget _personalStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    return _Fields(children: [
      Text(
        'POTRAZ requires us to confirm who owns each number. '
        'It takes about 5 minutes.',
        style: text.bodyLarge?.copyWith(fontSize: 16),
      ),
      _ReadOnlyValue(
        label: 'Phone number',
        value: _vm.phone,
        note: 'The number you are verifying.',
      ),
      _text(
        key: 'personal.firstName',
        label: 'First name',
        value: _vm.firstName,
        onChanged: _vm.setFirstName,
        keyboardType: TextInputType.name,
        capitalization: TextCapitalization.words,
        autofill: const [AutofillHints.givenName],
      ),
      _text(
        key: 'personal.lastName',
        label: 'Last name',
        value: _vm.lastName,
        onChanged: _vm.setLastName,
        keyboardType: TextInputType.name,
        capitalization: TextCapitalization.words,
        autofill: const [AutofillHints.familyName],
      ),
      _DateField(
        label: 'Date of birth',
        value: _vm.dateOfBirth,
        error: _vm.errors['personal.dateOfBirth'],
        onPick: () async {
          final picked = await _pickDate(
            context,
            initial: _vm.dateOfBirth ?? DateTime(now.year - 25, 1, 1),
            first: DateTime(now.year - 120, now.month, now.day),
            last: DateTime(now.year, now.month, now.day),
            help: 'Date of birth',
          );
          if (picked != null) _vm.setDateOfBirth(picked);
        },
      ),
      _Choice(
        label: 'Gender',
        options: kycGenderLabels,
        value: _vm.gender,
        error: _vm.errors['personal.gender'],
        onChanged: _vm.setGender,
      ),
      _text(
        key: 'personal.nationality',
        label: 'Nationality',
        value: _vm.nationality,
        onChanged: _vm.setNationality,
        capitalization: TextCapitalization.words,
        hint: 'For example, Zimbabwean',
        action: TextInputAction.done,
      ),
    ]);
  }

  Widget _addressStep(BuildContext context) {
    return _Fields(children: [
      _text(
        key: 'address.line1',
        label: 'Address',
        value: _vm.line1,
        onChanged: _vm.setLine1,
        keyboardType: TextInputType.streetAddress,
        capitalization: TextCapitalization.words,
        autofill: const [AutofillHints.streetAddressLine1],
        hint: 'House number and street',
      ),
      _text(
        key: 'address.line2',
        label: 'Address line 2 (optional)',
        value: _vm.line2,
        onChanged: _vm.setLine2,
        keyboardType: TextInputType.streetAddress,
        capitalization: TextCapitalization.words,
        autofill: const [AutofillHints.streetAddressLine2],
        hint: 'Suburb or area',
      ),
      _text(
        key: 'address.city',
        label: 'City or town',
        value: _vm.city,
        onChanged: _vm.setCity,
        capitalization: TextCapitalization.words,
        autofill: const [AutofillHints.addressCity],
      ),
      _text(
        key: 'address.country',
        label: 'Country',
        value: _vm.country,
        onChanged: _vm.setCountry,
        capitalization: TextCapitalization.words,
        autofill: const [AutofillHints.countryName],
        action: TextInputAction.done,
      ),
    ]);
  }

  Widget _idStep(BuildContext context) {
    final now = DateTime.now();
    final isPassport = _vm.idType == 'passport';
    final masked = _vm.idNumberMasked;
    final String helper;
    if (masked != null && (_vm.newIdNumber ?? '').trim().isEmpty) {
      helper = 'Leave blank to keep the number you entered before.';
    } else if (isPassport) {
      helper = '6 to 12 letters or digits.';
    } else {
      helper = 'Like 63-123456-A-42.';
    }
    return _Fields(children: [
      _Choice(
        label: 'ID type',
        options: kycIdTypeLabels,
        value: _vm.idType,
        error: _vm.errors['identification.idType'],
        onChanged: _vm.setIdType,
      ),
      _text(
        key: 'identification.idNumber',
        label: 'ID number',
        // The server never returns the plain number, so the field starts
        // empty and shows the masked value as a hint.
        value: null,
        hint: masked,
        helper: helper,
        onChanged: _vm.setIdNumber,
        capitalization: TextCapitalization.characters,
        sensitive: true,
        action: isPassport ? TextInputAction.next : TextInputAction.done,
      ),
      if (isPassport)
        _DateField(
          label: 'Passport expiry date',
          value: _vm.idExpiry,
          error: _vm.errors['identification.idExpiry'],
          onPick: () async {
            final first = DateTime(now.year, now.month, now.day + 1);
            final last = DateTime(now.year + 30, now.month, now.day);
            final picked = await _pickDate(
              context,
              initial: _vm.idExpiry ?? first,
              first: first,
              last: last,
              help: 'Passport expiry date',
            );
            if (picked != null) _vm.setIdExpiry(picked);
          },
        ),
    ]);
  }

  Widget _documentsStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kinds = _vm.documentKinds;
    if (_vm.idType == null) {
      return _Fields(children: [
        Text('Choose your ID type first, then add photos of it here.',
            style: text.bodyLarge?.copyWith(fontSize: 16)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _vm.goToStep(2),
            child: const Text('Go to ID details'),
          ),
        ),
      ]);
    }
    return _Fields(children: [
      Text(
        'Take a clear photo in good light, or choose a PDF. '
        'Each file must be under 8 MB.',
        style: text.bodyLarge?.copyWith(fontSize: 16),
      ),
      for (final kind in kinds)
        KycDocumentTile(
          key: ValueKey('kyc-doc-$kind'),
          label: kycDocumentLabel(kind),
          document: _vm.documentFor(kind),
          upload: _vm.uploads[kind],
          localPreview: _vm.localPreviews[kind],
          localIsPdf: _vm.localPdfs.contains(kind),
          error: _vm.documentErrors[kind] ?? _vm.errors['documents.$kind'],
          loadPreview: _vm.preview,
          onPick: () => _pickAndUpload(context, kind),
          onRetry: () => unawaited(_vm.retryUpload(kind)),
          onRemove: () {
            final doc = _vm.documentFor(kind);
            if (doc != null) unawaited(_vm.remove(doc.id));
          },
        ),
    ]);
  }

  Widget _reviewStep(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String or(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Not given' : v.trim();
    final typed = (_vm.newIdNumber ?? '').trim();
    final idShown = typed.isNotEmpty
        ? '${'*' * (typed.length > 3 ? typed.length - 3 : 0)}'
            '${typed.substring(typed.length > 3 ? typed.length - 3 : 0)}'
        : or(_vm.idNumberMasked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Check your details',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        if (_vm.submitError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.error),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_vm.submitError!,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontSize: 16, color: scheme.error)),
          ),
          const SizedBox(height: 16),
        ],
        _ReviewSection(
          title: kycStepLabels[0],
          onEdit: () => _vm.goToStep(0),
          rows: [
            ('First name', or(_vm.firstName)),
            ('Last name', or(_vm.lastName)),
            ('Date of birth', or(_formatDate(_vm.dateOfBirth))),
            ('Gender', or(kycGenderLabels[_vm.gender])),
            ('Nationality', or(_vm.nationality)),
            ('Phone number', or(_vm.phone)),
          ],
        ),
        _ReviewSection(
          title: kycStepLabels[1],
          onEdit: () => _vm.goToStep(1),
          rows: [
            ('Address', or(_vm.line1)),
            if ((_vm.line2 ?? '').trim().isNotEmpty)
              ('Address line 2', _vm.line2!.trim()),
            ('City or town', or(_vm.city)),
            ('Country', or(_vm.country)),
          ],
        ),
        _ReviewSection(
          title: kycStepLabels[2],
          onEdit: () => _vm.goToStep(2),
          rows: [
            ('ID type', or(kycIdTypeLabels[_vm.idType])),
            ('ID number', idShown),
            if (_vm.idType == 'passport')
              ('Expiry date', or(_formatDate(_vm.idExpiry))),
          ],
        ),
        _ReviewSection(
          title: kycStepLabels[3],
          onEdit: () => _vm.goToStep(3),
          rows: [
            for (final kind in _vm.documentKinds)
              (
                kycDocumentLabel(kind),
                _vm.documentFor(kind) != null ? 'Added' : 'Missing',
              ),
          ],
        ),
      ],
    );
  }

  // --- Bottom bar -----------------------------------------------------------

  Widget _bottomBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onReview = _vm.step == kycReviewStep;
    final busy = _vm.submitting;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: KycConstrained(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (_vm.step > 0)
                TextButton(
                  onPressed: busy ? null : _vm.back,
                  child: const Text('Back'),
                ),
              if (_vm.step > 0) const SizedBox(width: 12),
              // Expanded so long labels or large text wrap instead of
              // overflowing on narrow phones.
              Expanded(
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : onReview
                          ? () => unawaited(_vm.submit())
                          : () {
                              if (!_vm.next()) _announceErrors(context);
                            },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy) ...[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onSurface),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Text(
                          onReview ? 'Submit for review' : 'Next',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _announceErrors(BuildContext context) {
    final n = _vm.errors.length;
    SemanticsService.sendAnnouncement(
      View.of(context),
      n == 1 ? 'One detail needs fixing.' : '$n details need fixing.',
      Directionality.of(context),
    );
  }

  // --- Helpers --------------------------------------------------------------

  Widget _text({
    required String key,
    required String label,
    required String? value,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    List<String>? autofill,
    String? hint,
    String? helper,
    bool sensitive = false,
    TextInputAction action = TextInputAction.next,
  }) {
    final max = kycMaxLengths[key];
    return TextField(
      key: ValueKey('kyc-field-$key'),
      controller: _controller(key, value),
      onChanged: onChanged,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: action,
      autofillHints: autofill,
      inputFormatters: [
        if (max != null) LengthLimitingTextInputFormatter(max),
      ],
      autocorrect: !sensitive,
      enableSuggestions: !sensitive,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        errorText: _vm.errors[key],
        errorMaxLines: 2,
      ),
    );
  }

  Future<DateTime?> _pickDate(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required String help,
  }) {
    // Picker dates are local calendar dates; the view model stores them as
    // UTC midnight of the same calendar day.
    var start = DateTime(initial.year, initial.month, initial.day);
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;
    return showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: last,
      helpText: help,
      initialEntryMode: DatePickerEntryMode.calendar,
      builder: (context, child) {
        final t = Theme.of(context);
        return Theme(
          data: t.copyWith(
            textTheme: t.textTheme.copyWith(
              bodyLarge: t.textTheme.bodyLarge?.copyWith(fontSize: 16),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _pickAndUpload(BuildContext context, String kind) async {
    final source = await showModalBottomSheet<_Source>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(kycDocumentLabel(kind),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            _SheetOption(
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.of(context).pop(_Source.camera),
            ),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from photos',
              onTap: () => Navigator.of(context).pop(_Source.gallery),
            ),
            _SheetOption(
              icon: Icons.description_outlined,
              label: 'Choose a file (PDF, JPG or PNG)',
              onTap: () => Navigator.of(context).pop(_Source.file),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    KycPickedFile? file;
    try {
      file = await _pick(source);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(this.context)?.showSnackBar(const SnackBar(
        content: Text(
            'Could not open the camera or your files. Check the app permissions.'),
      ));
      return;
    }
    if (file == null) return;
    await _vm.upload(kind, file);
  }

  Future<KycPickedFile?> _pick(_Source source) async {
    if (source == _Source.file) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      final f = result?.files.singleOrNull;
      final bytes = f?.bytes;
      if (f == null || bytes == null) return null;
      return KycPickedFile(bytes: bytes, filename: f.name);
    }
    final x = await ImagePicker().pickImage(
      source:
          source == _Source.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
    );
    if (x == null) return null;
    return KycPickedFile(bytes: await x.readAsBytes(), filename: x.name);
  }
}

enum _Source { camera, gallery, file }

/// Local overrides so the form follows the KYC design rules whatever the app
/// theme says: hairline borders, radius 8 for buttons, 6 for inputs, 48 px
/// touch targets, 16 px text.
class _Fields extends StatelessWidget {
  const _Fields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            children[i],
          ],
        ],
      );
}

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.vm});

  final KycFormViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    final Widget content;
    switch (vm.saveState) {
      case KycSaveState.idle:
        content = const SizedBox.shrink();
      case KycSaveState.saving:
        content = Text('Saving…',
            style: style?.copyWith(color: scheme.onSurfaceVariant));
      case KycSaveState.saved:
        content = Text('Saved',
            style: style?.copyWith(color: scheme.onSurfaceVariant));
      case KycSaveState.error:
        content = Row(
          children: [
            Flexible(
              child: Text(vm.saveError ?? 'Not saved. Check your connection.',
                  style: style?.copyWith(color: scheme.error)),
            ),
            TextButton(
              onPressed: () => unawaited(vm.retrySave()),
              child: const Text('Try again'),
            ),
          ],
        );
    }
    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(alignment: Alignment.centerLeft, child: content),
      ),
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue(
      {required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: body?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: body?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(note, style: body?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.error,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final shown = _formatDate(value);
    return Semantics(
      button: true,
      label: [label, if (shown.isNotEmpty) shown, if (error != null) error!]
          .join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(6),
        child: InputDecorator(
          isEmpty: shown.isEmpty,
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            errorMaxLines: 2,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(shown, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.options,
    required this.value,
    required this.error,
    required this.onChanged,
  });

  final String label;
  final Map<String, String> options;
  final String? value;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = options.containsKey(value) ? {value!} : <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontSize: 16, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final e in options.entries)
              ButtonSegment(value: e.key, label: Text(e.value)),
          ],
          selected: selected,
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) onChanged(s.first);
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontSize: 14, color: scheme.error)),
        ],
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  final String title;
  final VoidCallback onEdit;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(fontSize: 16);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: body?.copyWith(fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: onEdit,
              child: Text('Edit', semanticsLabel: 'Edit $title'),
            ),
          ]),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140),
                    child: Text(label,
                        style: body?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  Text(value, style: body),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 56,
        leading: Icon(icon),
        title: Text(label, style: const TextStyle(fontSize: 16)),
        onTap: onTap,
      );
}
