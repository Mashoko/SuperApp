import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/payment_method.dart';
import '../../models/pm_transaction.dart';
import '../viewmodels/payment_methods_viewmodel.dart';

// ── Palette (matches HTML prototype) ──────────────────────────────────────────
const _kBlue       = Color(0xFF185FA5);
const _kBlueBg     = Color(0xFFE6F1FB);
const _kGreenIco   = Color(0xFF3B6D11);
const _kGreenBg    = Color(0xFFEAF3DE);
const _kGreenText  = Color(0xFF27500A);
const _kAmberIco   = Color(0xFF854F0B);
const _kAmberBg    = Color(0xFFFAEEDA);
const _kAmberText  = Color(0xFF633806);
const _kIndigoIco  = Color(0xFF534AB7);
const _kIndigoBg   = Color(0xFFEEEDFE);
const _kBankIco    = Color(0xFF5F5E5A);
const _kBankBg     = Color(0xFFF1EFE8);
const _kRed        = Color(0xFFA32D2D);
const _kRedBgBadge = Color(0xFFFCEBEB);
const _kBorder     = Color(0xFFE0E0E0);
const _kBg         = Color(0xFFF7F8FA);
const _kCard       = Colors.white;
const _kTextPri    = Color(0xFF1A1A1A);
const _kTextSec    = Color(0xFF6B7280);

// ── Screen enum ────────────────────────────────────────────────────────────────
enum _Screen {
  methodsList,
  addOptions,
  addCard,
  addMobile,
  addBank,
  otp,
  methodSuccess,
  methodDetail,
  checkout,
  processing,
  paySuccess,
  payFailed,
  history,
}

class PaymentMethodsView extends StatefulWidget {
  const PaymentMethodsView({super.key});

  @override
  State<PaymentMethodsView> createState() => _PaymentMethodsViewState();
}

class _PaymentMethodsViewState extends State<PaymentMethodsView> {
  final _vm = PaymentMethodsViewModel();

  // Internal navigation stack
  final List<_Screen> _stack = [_Screen.methodsList];
  _Screen get _current => _stack.last;

  // OTP back-target (which form triggered OTP)
  _Screen _otpFrom = _Screen.addCard;

  // Detail screen context
  PaymentMethod? _detailMethod;

  // Resolves to the default method; will become dynamic when checkout orders are wired to a real API.
  final String _selectedPayMethodId = '';

  // OTP digits
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocuses = List.generate(6, (_) => FocusNode());

  // Form controllers
  final _cardHolderCtrl  = TextEditingController();
  final _cardNumberCtrl  = TextEditingController();
  final _cardExpiryCtrl  = TextEditingController();
  final _cardCvvCtrl     = TextEditingController();
  final _mobilePhoneCtrl = TextEditingController();
  String _mobileProvider = 'EcoCash';
  final _bankNameCtrl    = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankHolderCtrl  = TextEditingController();
  int _bankTab = 0;

  @override
  void dispose() {
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocuses)     { f.dispose(); }
    _cardHolderCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    _mobilePhoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _bankHolderCtrl.dispose();
    super.dispose();
  }

  void _push(_Screen s) => setState(() => _stack.add(s));
  void _pop()           => setState(() { if (_stack.length > 1) _stack.removeLast(); });
  void _go(_Screen s)   => setState(() { _stack
    ..clear()
    ..add(s); });

  int get _activeTab {
    switch (_current) {
      case _Screen.checkout:
      case _Screen.processing:
      case _Screen.paySuccess:
      case _Screen.payFailed:
        return 1;
      case _Screen.history:
        return 2;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stack.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stack.length > 1) _pop();
      },
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildNavTabs(),
              Expanded(child: _buildCurrentScreen()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nav tabs ──────────────────────────────────────────────────────────────

  Widget _buildNavTabs() {
    final labels = ['Methods', 'Checkout', 'History'];
    final targets = [_Screen.methodsList, _Screen.checkout, _Screen.history];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: List.generate(3, (i) {
          final active = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _go(targets[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? _kBlue : _kCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: active ? _kBlue : _kBorder, width: 0.5),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? Colors.white : _kTextSec,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Screen router ─────────────────────────────────────────────────────────

  Widget _buildCurrentScreen() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_current),
        child: switch (_current) {
          _Screen.methodsList  => _MethodsListScreen(vm: _vm, onAdd: () => _push(_Screen.addOptions), onDetail: (m) { _detailMethod = m; _push(_Screen.methodDetail); }),
          _Screen.addOptions   => _AddOptionsScreen(onBack: _pop, onCard: () => _push(_Screen.addCard), onMobile: () => _push(_Screen.addMobile), onBank: () => _push(_Screen.addBank)),
          _Screen.addCard      => _AddCardScreen(onBack: _pop, holderCtrl: _cardHolderCtrl, numberCtrl: _cardNumberCtrl, expiryCtrl: _cardExpiryCtrl, cvvCtrl: _cardCvvCtrl, onContinue: () { _otpFrom = _Screen.addCard; _push(_Screen.otp); }),
          _Screen.addMobile    => _AddMobileScreen(onBack: _pop, phoneCtrl: _mobilePhoneCtrl, provider: _mobileProvider, onProviderChange: (v) => setState(() => _mobileProvider = v), onContinue: () { _otpFrom = _Screen.addMobile; _push(_Screen.otp); }),
          _Screen.addBank      => _AddBankScreen(onBack: _pop, nameCtrl: _bankNameCtrl, accountCtrl: _bankAccountCtrl, holderCtrl: _bankHolderCtrl, activeTab: _bankTab, onTabChange: (i) => setState(() => _bankTab = i), onContinue: () { _otpFrom = _Screen.addBank; _push(_Screen.otp); }),
          _Screen.otp          => _OtpScreen(onBack: () => _go(_otpFrom), controllers: _otpControllers, focuses: _otpFocuses, onVerify: () { _vm.addMethod(_buildNewMethod()); _go(_Screen.methodSuccess); }),
          _Screen.methodSuccess=> _MethodSuccessScreen(onDone: () => _go(_Screen.methodsList)),
          _Screen.methodDetail => _MethodDetailScreen(method: _detailMethod!, vm: _vm, onBack: _pop, onDeleted: () => _go(_Screen.methodsList)),
          _Screen.checkout     => const _CheckoutEmptyScreen(),
          _Screen.processing   => const _ProcessingScreen(),
          _Screen.paySuccess   => _PaySuccessScreen(method: _resolveMethod(), onDone: () => _go(_Screen.methodsList), onHistory: () => _go(_Screen.history)),
          _Screen.payFailed    => _PayFailedScreen(method: _resolveMethod(), onRetry: () => _go(_Screen.checkout), onBack: () => _go(_Screen.methodsList)),
          _Screen.history      => _HistoryScreen(vm: _vm),
        },
      ),
    );
  }

  PaymentMethod? _resolveMethod() =>
      _vm.methods.where((m) => m.id == _selectedPayMethodId).firstOrNull ??
      _vm.defaultMethod;

  PaymentMethod _buildNewMethod() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (_otpFrom == _Screen.addCard) {
      final last4 = _cardNumberCtrl.text.replaceAll(' ', '').padLeft(4).substring(
            (_cardNumberCtrl.text.replaceAll(' ', '').length - 4).clamp(0, 100));
      return PaymentMethod(id: id, type: PaymentMethodType.visa,
          displayName: 'Visa ****$last4', subtitle: 'Expires ${_cardExpiryCtrl.text}', status: MethodStatus.verified);
    }
    if (_otpFrom == _Screen.addMobile) {
      final masked = _mobilePhoneCtrl.text.length >= 7
          ? '${_mobilePhoneCtrl.text.substring(0, 4)} *** ${_mobilePhoneCtrl.text.substring(_mobilePhoneCtrl.text.length - 3)}'
          : _mobilePhoneCtrl.text;
      final type = switch (_mobileProvider) {
        'OneMoney' => PaymentMethodType.onemoney,
        'InnBucks' => PaymentMethodType.innbucks,
        _ => PaymentMethodType.ecocash,
      };
      return PaymentMethod(id: id, type: type, displayName: _mobileProvider,
          subtitle: masked, status: MethodStatus.verified);
    }
    return PaymentMethod(id: id, type: PaymentMethodType.bank,
        displayName: _bankNameCtrl.text.isNotEmpty ? _bankNameCtrl.text : 'Bank Account',
        subtitle: _bankAccountCtrl.text, status: MethodStatus.pending);
  }
}

// ── Screen: methods list ───────────────────────────────────────────────────────

class _MethodsListScreen extends StatelessWidget {
  const _MethodsListScreen({required this.vm, required this.onAdd, required this.onDetail});
  final PaymentMethodsViewModel vm;
  final VoidCallback onAdd;
  final void Function(PaymentMethod) onDetail;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (_, __) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TopBar(title: 'Payment methods'),
              const _SectionLabel('Linked methods'),
              if (vm.methods.isEmpty)
                _PmCard(child: const _EmptyState(
                  icon: Icons.credit_card_outlined,
                  message: 'No methods linked',
                ))
              else
                _PmCard(
                  child: Column(
                    children: vm.methods
                        .map((m) => _MethodRow(method: m, onTap: () => onDetail(m)))
                        .toList(),
                  ),
                ),
              const SizedBox(height: 8),
              _AddButton(onTap: onAdd),
            ],
          ),
        );
      },
    );
  }
}

// ── Screen: add options ────────────────────────────────────────────────────────

class _AddOptionsScreen extends StatelessWidget {
  const _AddOptionsScreen({required this.onBack, required this.onCard, required this.onMobile, required this.onBank});
  final VoidCallback onBack, onCard, onMobile, onBank;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(title: 'Add payment method', onBack: onBack),
          _PmCard(
            child: Column(children: [
              _OptionRow(icon: Icons.credit_card, bg: _kBlueBg, iconColor: _kBlue, title: 'Visa / Mastercard', sub: 'Debit or credit card', onTap: onCard),
              _OptionRow(icon: Icons.phone_android, bg: _kGreenBg, iconColor: _kGreenIco, title: 'EcoCash', sub: 'Mobile money', onTap: onMobile),
              _OptionRow(icon: Icons.phone_android, bg: _kAmberBg, iconColor: _kAmberIco, title: 'OneMoney', sub: 'Mobile money', onTap: onMobile),
              _OptionRow(icon: Icons.account_balance_wallet_outlined, bg: _kIndigoBg, iconColor: _kIndigoIco, title: 'InnBucks', sub: 'Mobile wallet', onTap: onMobile),
              _OptionRow(icon: Icons.account_balance_outlined, bg: _kBankBg, iconColor: _kBankIco, title: 'Bank account / ZIPIT', sub: 'ZSE clearing', onTap: onBank),
              _OptionRow(icon: Icons.paypal, bg: _kBlueBg, iconColor: _kBlue, title: 'PayPal', sub: 'International payments', onTap: onMobile, last: true),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Screen: add card ───────────────────────────────────────────────────────────

class _AddCardScreen extends StatelessWidget {
  const _AddCardScreen({required this.onBack, required this.holderCtrl, required this.numberCtrl, required this.expiryCtrl, required this.cvvCtrl, required this.onContinue});
  final VoidCallback onBack, onContinue;
  final TextEditingController holderCtrl, numberCtrl, expiryCtrl, cvvCtrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(title: 'Add card', onBack: onBack),
          _PmCard(
            child: Column(children: [
              _FormField(label: 'Cardholder name', hint: 'Rose Chinyemba', ctrl: holderCtrl),
              _FormField(label: 'Card number', hint: '0000 0000 0000 0000', ctrl: numberCtrl, keyboard: TextInputType.number, inputFormatters: [_CardNumberFormatter()]),
              Row(children: [
                Expanded(child: _FormField(label: 'Expiry', hint: 'MM / YY', ctrl: expiryCtrl, inputFormatters: [_ExpiryFormatter()])),
                const SizedBox(width: 10),
                Expanded(child: _FormField(label: 'CVV', hint: '•••', ctrl: cvvCtrl, keyboard: TextInputType.number, obscure: true, maxLength: 4)),
              ]),
            ]),
          ),
          const _HintText(text: '🔒  Card data is encrypted — we never store raw details'),
          const SizedBox(height: 12),
          _PrimaryBtn(label: 'Continue', onTap: onContinue),
          _GhostBtn(label: 'Cancel', onTap: onBack),
        ],
      ),
    );
  }
}

// ── Screen: add mobile money ───────────────────────────────────────────────────

class _AddMobileScreen extends StatelessWidget {
  const _AddMobileScreen({required this.onBack, required this.phoneCtrl, required this.provider, required this.onProviderChange, required this.onContinue});
  final VoidCallback onBack, onContinue;
  final TextEditingController phoneCtrl;
  final String provider;
  final void Function(String) onProviderChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(title: 'Add mobile money', onBack: onBack),
          _PmCard(
            child: Column(children: [
              _DropdownField(label: 'Provider', value: provider, items: ['EcoCash', 'OneMoney', 'InnBucks'], onChanged: onProviderChange),
              _FormField(label: 'Phone number', hint: '+263 77 xxx xxxx', ctrl: phoneCtrl, keyboard: TextInputType.phone),
            ]),
          ),
          const _HintText(text: 'A verification code will be sent to this number'),
          const SizedBox(height: 12),
          _PrimaryBtn(label: 'Send verification code', onTap: onContinue),
          _GhostBtn(label: 'Cancel', onTap: onBack),
        ],
      ),
    );
  }
}

// ── Screen: add bank ───────────────────────────────────────────────────────────

class _AddBankScreen extends StatelessWidget {
  const _AddBankScreen({required this.onBack, required this.nameCtrl, required this.accountCtrl, required this.holderCtrl, required this.activeTab, required this.onTabChange, required this.onContinue});
  final VoidCallback onBack, onContinue;
  final TextEditingController nameCtrl, accountCtrl, holderCtrl;
  final int activeTab;
  final void Function(int) onTabChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(title: 'Add bank account', onBack: onBack),
          _PmCard(
            child: Column(children: [
              _DropdownField(label: 'Bank name', value: nameCtrl.text.isEmpty ? 'ZB Bank' : nameCtrl.text, items: ['ZB Bank', 'CBZ', 'Stanbic', 'FBC', 'Ecobank'], onChanged: (v) => nameCtrl.text = v),
              _FormField(label: 'Account number', hint: '000 000 0000', ctrl: accountCtrl, keyboard: TextInputType.number),
              _FormField(label: 'Account holder name', hint: 'Full name as on account', ctrl: holderCtrl),
            ]),
          ),
          const _HintText(text: 'Verification via micro-deposit (1–2 business days) or OTP'),
          const SizedBox(height: 10),
          _TabRow(labels: ['OTP (instant)', 'Micro-deposit'], active: activeTab, onTap: onTabChange),
          const SizedBox(height: 4),
          _PrimaryBtn(label: activeTab == 0 ? 'Send OTP' : 'Start micro-deposit', onTap: onContinue),
          _GhostBtn(label: 'Cancel', onTap: onBack),
        ],
      ),
    );
  }
}

// ── Screen: OTP ───────────────────────────────────────────────────────────────

class _OtpScreen extends StatelessWidget {
  const _OtpScreen({required this.onBack, required this.controllers, required this.focuses, required this.onVerify});
  final VoidCallback onBack, onVerify;
  final List<TextEditingController> controllers;
  final List<FocusNode> focuses;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(title: 'Enter verification code', onBack: onBack),
          const SizedBox(height: 8),
          const Center(
            child: Text('A 6-digit code was sent to your device',
                style: TextStyle(fontSize: 13, color: _kTextSec)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) => _OtpBox(
              ctrl: controllers[i],
              focus: focuses[i],
              next: i < 5 ? focuses[i + 1] : null,
            )),
          ),
          const SizedBox(height: 24),
          _PrimaryBtn(label: 'Verify', onTap: onVerify),
          const SizedBox(height: 12),
          Center(
            child: Text.rich(TextSpan(
              style: const TextStyle(fontSize: 12, color: _kTextSec),
              children: [
                const TextSpan(text: "Didn't receive it?  "),
                WidgetSpan(child: GestureDetector(
                  onTap: () {},
                  child: const Text('Resend', style: TextStyle(color: _kBlue, fontSize: 12)),
                )),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

// ── Screen: success (after adding method) ─────────────────────────────────────

class _MethodSuccessScreen extends StatelessWidget {
  const _MethodSuccessScreen({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _TopBar(title: ''),
          const Spacer(),
          const _StatusIcon(icon: Icons.check_circle_outline, color: _kGreenIco, bg: _kGreenBg),
          const SizedBox(height: 16),
          const Text('Method added', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kTextPri)),
          const SizedBox(height: 6),
          const Text('Your payment method is now linked and ready to use', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _kTextSec)),
          const Spacer(),
          _PrimaryBtn(label: 'Done', onTap: onDone),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Screen: method detail ─────────────────────────────────────────────────────

class _MethodDetailScreen extends StatelessWidget {
  const _MethodDetailScreen({required this.method, required this.vm, required this.onBack, required this.onDeleted});
  final PaymentMethod method;
  final PaymentMethodsViewModel vm;
  final VoidCallback onBack, onDeleted;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(title: method.displayName, onBack: onBack),
          _PmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _MethodIcon(type: method.type, size: 44),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _kTextPri)),
                      const SizedBox(height: 2),
                      Text(_detailSubtitle(method), style: const TextStyle(fontSize: 12, color: _kTextSec)),
                    ],
                  ),
                ]),
                const Divider(height: 24, color: _kBorder, thickness: 0.5),
                _ActionRow(icon: Icons.star_border, label: 'Set as default', onTap: () { vm.setDefault(method.id); onBack(); }),
                _ActionRow(icon: Icons.edit_outlined, label: 'Rename', onTap: () {}),
                _ActionRow(icon: Icons.info_outline, label: 'View details', onTap: () {}),
                _ActionRow(icon: Icons.delete_outline, label: 'Remove method', danger: true, onTap: () { vm.removeMethod(method.id); onDeleted(); }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _detailSubtitle(PaymentMethod m) {
    final statusStr = switch (m.status) {
      MethodStatus.defaultMethod => 'Default',
      MethodStatus.verified      => 'Verified',
      MethodStatus.pending       => 'Pending verification',
    };
    return '$statusStr · ${m.subtitle}';
  }
}

// ── Screen: checkout empty state ─────────────────────────────────────────────

class _CheckoutEmptyScreen extends StatelessWidget {
  const _CheckoutEmptyScreen();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TopBar(title: 'Checkout'),
          const Expanded(
            child: Center(
              child: _EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'No pending payments',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Screen: processing ────────────────────────────────────────────────────────

class _ProcessingScreen extends StatelessWidget {
  const _ProcessingScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatusIcon(icon: Icons.refresh, color: _kBlue, bg: _kBlueBg, spin: true),
          SizedBox(height: 16),
          Text('Processing payment…', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kTextPri)),
          SizedBox(height: 6),
          Text('Please wait, do not close this screen', style: TextStyle(fontSize: 13, color: _kTextSec)),
        ],
      ),
    );
  }
}

// ── Screen: pay success ───────────────────────────────────────────────────────

class _PaySuccessScreen extends StatelessWidget {
  const _PaySuccessScreen({required this.method, required this.onDone, required this.onHistory});
  final PaymentMethod? method;
  final VoidCallback onDone, onHistory;

  @override
  Widget build(BuildContext context) {
    final methodLabel = method?.displayName ?? '—';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _TopBar(title: ''),
          const Spacer(),
          const _StatusIcon(icon: Icons.check_circle_outline, color: _kGreenIco, bg: _kGreenBg),
          const SizedBox(height: 16),
          const Text('Payment successful', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kTextPri)),
          const SizedBox(height: 6),
          Text(methodLabel, style: const TextStyle(fontSize: 13, color: _kTextSec)),
          const SizedBox(height: 16),
          _ReceiptCard(methodLabel: methodLabel),
          const Spacer(),
          _PrimaryBtn(label: 'Done', onTap: onDone),
          _GhostBtn(label: 'View receipt', onTap: onHistory),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Screen: pay failed ────────────────────────────────────────────────────────

class _PayFailedScreen extends StatelessWidget {
  const _PayFailedScreen({required this.method, required this.onRetry, required this.onBack});
  final PaymentMethod? method;
  final VoidCallback onRetry, onBack;

  @override
  Widget build(BuildContext context) {
    final methodLabel = method?.displayName ?? 'selected method';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _TopBar(title: ''),
          const Spacer(),
          const _StatusIcon(icon: Icons.cancel_outlined, color: _kRed, bg: _kRedBgBadge),
          const SizedBox(height: 16),
          const Text('Payment failed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kTextPri)),
          const SizedBox(height: 6),
          Text('Could not process payment via $methodLabel', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _kTextSec)),
          const Spacer(),
          _PrimaryBtn(label: 'Try another method', onTap: onRetry),
          _GhostBtn(label: 'Back to methods', onTap: onBack),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Screen: history ───────────────────────────────────────────────────────────

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen({required this.vm});
  final PaymentMethodsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return ListenableBuilder(
      listenable: vm,
      builder: (_, __) {
        final txs = vm.transactions;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _TopBar(title: 'Transaction history'),
              if (txs.isEmpty)
                const _PmCard(child: _EmptyState(icon: Icons.receipt_long_outlined, message: 'No transactions yet'))
              else ...[
                const _SectionLabel('Recent'),
                _PmCard(
                  child: Column(
                    children: txs.map((tx) => _TxRow(tx: tx, fmt: fmt)).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: const Icon(Icons.arrow_back_ios, size: 18, color: _kTextSec),
            ),
            const SizedBox(width: 8),
          ],
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _kTextPri)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _kTextSec, letterSpacing: 0.6)),
    );
  }
}

class _PmCard extends StatelessWidget {
  const _PmCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child,
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({required this.method, required this.onTap});
  final PaymentMethod method;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _kBorder, width: 0.5)),
        ),
        child: Row(children: [
          _MethodIcon(type: method.type),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kTextPri)),
              Text(method.subtitle, style: const TextStyle(fontSize: 12, color: _kTextSec)),
            ],
          )),
          _StatusBadge(status: method.status),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: _kTextSec),
        ]),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.icon, required this.bg, required this.iconColor, required this.title, required this.sub, required this.onTap, this.last = false});
  final IconData icon;
  final Color bg, iconColor;
  final String title, sub;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder, width: 0.5))),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kTextPri)),
            Text(sub, style: const TextStyle(fontSize: 12, color: _kTextSec)),
          ])),
          const Icon(Icons.chevron_right, size: 16, color: _kTextSec),
        ]),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.fmt});
  final PmTransaction tx;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    final (icoBg, icoColor) = _methodColors(tx.methodType);
    final (statusColor, statusLabel) = switch (tx.status) {
      TransactionStatus.completed => (const Color(0xFF3B6D11), 'Completed'),
      TransactionStatus.pending   => (const Color(0xFF854F0B), 'Pending'),
      TransactionStatus.failed    => (const Color(0xFFA32D2D), 'Failed'),
    };

    final icon = switch (tx.methodType) {
      PaymentMethodType.visa || PaymentMethodType.mastercard => Icons.credit_card,
      PaymentMethodType.ecocash || PaymentMethodType.onemoney => Icons.phone_android,
      PaymentMethodType.innbucks => Icons.account_balance_wallet_outlined,
      PaymentMethodType.bank => Icons.account_balance_outlined,
      PaymentMethodType.paypal => Icons.paypal,
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder, width: 0.5))),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: icoBg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: icoColor, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tx.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _kTextPri)),
          Text('${fmt.format(tx.date)} · ${tx.methodLabel} · ${tx.reference}', style: const TextStyle(fontSize: 11, color: _kTextSec)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('\$${tx.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _kTextPri)),
          Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor)),
        ]),
      ]),
    );
  }
}

class _MethodIcon extends StatelessWidget {
  const _MethodIcon({required this.type, this.size = 36});
  final PaymentMethodType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, color) = _methodColors(type);
    final icon = switch (type) {
      PaymentMethodType.visa || PaymentMethodType.mastercard => Icons.credit_card,
      PaymentMethodType.ecocash || PaymentMethodType.onemoney => Icons.phone_android,
      PaymentMethodType.innbucks => Icons.account_balance_wallet_outlined,
      PaymentMethodType.bank => Icons.account_balance_outlined,
      PaymentMethodType.paypal => Icons.paypal,
    };
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.25)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final MethodStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, text) = switch (status) {
      MethodStatus.defaultMethod => ('Default',  _kGreenBg,  _kGreenText),
      MethodStatus.verified      => ('Verified', _kGreenBg,  _kGreenText),
      MethodStatus.pending       => ('Pending',  _kAmberBg,  _kAmberText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: text)),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? _kRed : _kTextPri;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder, width: 0.5))),
        child: Row(children: [
          Icon(icon, size: 20, color: danger ? _kRed : _kTextSec),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: c)),
        ]),
      ),
    );
  }
}

class _StatusIcon extends StatefulWidget {
  const _StatusIcon({required this.icon, required this.color, required this.bg, this.spin = false});
  final IconData icon;
  final Color color, bg;
  final bool spin;

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    Widget ico = Icon(widget.icon, color: widget.color, size: 28);
    if (widget.spin) {
      ico = RotationTransition(turns: _ctrl, child: ico);
    }
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(color: widget.bg, shape: BoxShape.circle),
      child: Center(child: ico),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.methodLabel});
  final String methodLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        _ReceiptRow(label: 'Date', value: DateFormat('d MMM yyyy').format(DateTime.now())),
        _ReceiptRow(label: 'Method', value: methodLabel),
      ]),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _kTextSec)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextPri)),
      ]),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.hint, required this.ctrl, this.keyboard, this.obscure = false, this.maxLength, this.inputFormatters});
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType? keyboard;
  final bool obscure;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _kTextSec)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            obscureText: obscure,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: const TextStyle(fontSize: 14, color: _kTextPri),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _kTextSec, fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder, width: 0.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder, width: 0.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1)),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});
  final String label, value;
  final List<String> items;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final current = items.contains(value) ? value : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _kTextSec)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: current,
            style: const TextStyle(fontSize: 14, color: _kTextPri),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder, width: 0.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder, width: 0.5)),
            ),
            items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.labels, required this.active, required this.onTap});
  final List<String> labels;
  final int active;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(labels.length, (i) {
        final sel = active == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: sel ? _kBlue : _kBorder, width: sel ? 2 : 0.5)),
              ),
              child: Text(labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: sel ? _kBlue : _kTextSec, fontWeight: sel ? FontWeight.w500 : FontWeight.normal),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.ctrl, required this.focus, this.next});
  final TextEditingController ctrl;
  final FocusNode focus;
  final FocusNode? next;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: ctrl,
        focusNode: focus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: _kTextPri),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder, width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBorder, width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && next != null) next!.requestFocus();
        },
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder, width: 0.5, style: BorderStyle.solid),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add, size: 18, color: _kTextSec),
          SizedBox(width: 6),
          Text('Add payment method', style: TextStyle(fontSize: 14, color: _kTextSec)),
        ]),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kBlue.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kTextSec,
          side: const BorderSide(color: _kBorder, width: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _kTextSec))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Icon(icon, size: 36, color: _kTextSec),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(fontSize: 13, color: _kTextSec)),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

(Color, Color) _methodColors(PaymentMethodType type) => switch (type) {
  PaymentMethodType.visa || PaymentMethodType.mastercard || PaymentMethodType.paypal => (_kBlueBg, _kBlue),
  PaymentMethodType.ecocash => (_kGreenBg, _kGreenIco),
  PaymentMethodType.onemoney => (_kAmberBg, _kAmberIco),
  PaymentMethodType.innbucks => (_kIndigoBg, _kIndigoIco),
  PaymentMethodType.bank => (_kBankBg, _kBankIco),
};

// ── Input formatters ──────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue n) {
    final digits = n.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return n.copyWith(text: str, selection: TextSelection.collapsed(offset: str.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue n) {
    final digits = n.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 2) {
      final str = '${digits.substring(0, 2)} / ${digits.substring(2, digits.length.clamp(0, 4))}';
      return n.copyWith(text: str, selection: TextSelection.collapsed(offset: str.length));
    }
    return n.copyWith(text: digits);
  }
}
