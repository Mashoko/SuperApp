// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/inject.dart';
import '../../../../core/services/otp_auth_service.dart';
import '../../../../shared/theme/theme_provider.dart';

import '../../data/faq_data.dart';
import '../../../dash/presentation/widgets/dash_sheet.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

// Replace with your actual WhatsApp support number (digits only, country code first)
const _kWhatsAppNumber = '263771234567';
const _kAppVersion     = '4.11.50';
const _kSupportEmail   = 'support@firststreet.co.zw';
const _kSupportPhone   = 'tel:+263771234567';
const _kWebsite        = 'https://firststreet.co.zw';

// ─── Data models ─────────────────────────────────────────────────────────────

enum _ServiceStatus { operational, degraded, outage }
enum _TicketStatus  { open, inProgress, resolved }
enum _Screen {
  main, reportProblem, myTickets, ticketDetail,
  systemStatus, emergency, faqCategory, serviceHelp
}

class _ServiceTopic {
  final String label;
  final IconData icon;
  const _ServiceTopic(this.label, this.icon);
}

class _ServiceCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<_ServiceTopic> topics;
  const _ServiceCategory({required this.name, required this.icon, required this.color, required this.topics});
}

class _SysService {
  final String name;
  final IconData icon;
  final _ServiceStatus status;
  const _SysService(this.name, this.icon, this.status);
}

class _Ticket {
  final String id;
  final String title;
  final String category;
  final _TicketStatus status;
  final DateTime updatedAt;
  const _Ticket({required this.id, required this.title, required this.category, required this.status, required this.updatedAt});
}

// ─── Static content ───────────────────────────────────────────────────────────


const _serviceData = [
  _ServiceCategory(name: 'Calling', icon: Icons.call_outlined, color: Color(0xFF00BCD4), topics: [
    _ServiceTopic('Buy Airtime', Icons.phone_android),
    _ServiceTopic('International Calls', Icons.public),
    _ServiceTopic('Call Quality Issues', Icons.signal_cellular_alt),
    _ServiceTopic('VoIP Setup', Icons.settings_phone),
    _ServiceTopic('Missed Calls', Icons.phone_missed),
    _ServiceTopic('Account Balance', Icons.account_balance_wallet),
  ]),
  _ServiceCategory(name: 'Shopping', icon: Icons.shopping_bag_outlined, color: Color(0xFF9C27B0), topics: [
    _ServiceTopic('My Orders', Icons.receipt_long),
    _ServiceTopic('Returns & Refunds', Icons.assignment_return),
    _ServiceTopic('Order Tracking', Icons.location_on),
    _ServiceTopic('Delivery Issues', Icons.local_shipping),
    _ServiceTopic('Cancel Order', Icons.cancel),
    _ServiceTopic('Wrong Item', Icons.swap_horiz),
  ]),
  _ServiceCategory(name: 'Utility Bills', icon: Icons.bolt_outlined, color: Color(0xFFFF9800), topics: [
    _ServiceTopic('Electricity (ZESA)', Icons.electric_bolt),
    _ServiceTopic('Water (ZINWA)', Icons.water_drop),
    _ServiceTopic('Internet', Icons.wifi),
    _ServiceTopic('DSTV / StarSat', Icons.tv),
    _ServiceTopic('Municipality', Icons.location_city),
    _ServiceTopic('School Fees', Icons.school),
  ]),
  _ServiceCategory(name: 'Wallet', icon: Icons.account_balance_wallet_outlined, color: Color(0xFF4CAF50), topics: [
    _ServiceTopic('Deposits', Icons.add_circle_outline),
    _ServiceTopic('Withdrawals', Icons.remove_circle_outline),
    _ServiceTopic('Transfers', Icons.swap_horiz),
    _ServiceTopic('Bank Cards', Icons.credit_card),
    _ServiceTopic('Transaction History', Icons.history),
    _ServiceTopic('Wallet Limits', Icons.speed),
  ]),
];

const _systemServices = [
  _SysService('Payments',       Icons.payment_outlined,                    _ServiceStatus.operational),
  _SysService('Calling & VoIP', Icons.call_outlined,                       _ServiceStatus.operational),
  _SysService('Shopping',       Icons.shopping_bag_outlined,               _ServiceStatus.operational),
  _SysService('Utility Bills',  Icons.bolt_outlined,                       _ServiceStatus.operational),
  _SysService('Wallet',         Icons.account_balance_wallet_outlined,     _ServiceStatus.operational),
  _SysService('API Services',   Icons.cloud_outlined,                      _ServiceStatus.operational),
];

final _mockTickets = [
  _Ticket(id: '#45821', title: 'Payment Pending — EcoCash',         category: 'Payments', status: _TicketStatus.inProgress, updatedAt: DateTime.now().subtract(const Duration(hours: 2))),
  _Ticket(id: '#45803', title: 'ZESA Token Not Received',           category: 'Bills',    status: _TicketStatus.resolved,   updatedAt: DateTime.now().subtract(const Duration(days: 1))),
  _Ticket(id: '#45790', title: 'Order Delivery Delayed',            category: 'Shopping', status: _TicketStatus.resolved,   updatedAt: DateTime.now().subtract(const Duration(days: 3))),
];

const _emergencyActions = [
  (icon: Icons.gpp_bad_outlined,      label: 'Account Compromised',       subtitle: 'Lock account & alert security', color: Color(0xFFE53935)),
  (icon: Icons.phone_locked_outlined, label: 'Lost Phone',                subtitle: 'Suspend access from this device', color: Color(0xFFE53935)),
  (icon: Icons.credit_card_off_outlined, label: 'Unauthorized Transaction', subtitle: 'Flag & dispute a charge', color: Color(0xFFFF9800)),
  (icon: Icons.lock_outline,          label: 'Freeze Wallet',             subtitle: 'Temporarily block all payments', color: Color(0xFFFF9800)),
  (icon: Icons.person_off_outlined,   label: 'Freeze Account',            subtitle: 'Prevent all account activity', color: Color(0xFF9C27B0)),
  (icon: Icons.report_gmailerrorred_outlined, label: 'Report Fraud',      subtitle: 'Report suspicious activity', color: Color(0xFFE53935)),
];

// ─── Main view ────────────────────────────────────────────────────────────────

class HelpSupportView extends StatefulWidget {
  const HelpSupportView({super.key});
  @override
  State<HelpSupportView> createState() => _HelpSupportViewState();
}

class _HelpSupportViewState extends State<HelpSupportView> {
  final List<_Screen> _stack = [_Screen.main];
  FaqCategory? _activeFaqCategory;
  _ServiceCategory? _activeService;
  _Ticket? _activeTicket;

  void _push(_Screen s) => setState(() => _stack.add(s));
  void _pop() {
    if (_stack.length > 1) setState(() => _stack.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return PopScope(
      canPop: _stack.length == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stack.length > 1) _pop();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _buildScreen(isDark),
      ),
    );
  }

  Widget _buildScreen(bool isDark) {
    switch (_stack.last) {
      case _Screen.reportProblem:
        return _ReportProblemScreen(isDark: isDark, onBack: _pop);
      case _Screen.myTickets:
        return _MyTicketsScreen(isDark: isDark, onBack: _pop, tickets: _mockTickets,
            onTap: (t) { _activeTicket = t; _push(_Screen.ticketDetail); });
      case _Screen.ticketDetail:
        return _TicketDetailScreen(isDark: isDark, onBack: _pop, ticket: _activeTicket!);
      case _Screen.systemStatus:
        return _SystemStatusScreen(isDark: isDark, onBack: _pop);
      case _Screen.emergency:
        return _EmergencyScreen(isDark: isDark, onBack: _pop);
      case _Screen.faqCategory:
        return _FaqCategoryScreen(isDark: isDark, onBack: _pop, category: _activeFaqCategory!);
      case _Screen.serviceHelp:
        return _ServiceHelpScreen(isDark: isDark, onBack: _pop, service: _activeService!,
            onFaqTap: (cat) { _activeFaqCategory = cat; _push(_Screen.faqCategory); });
      case _Screen.main:
        return _MainScreen(
          isDark: isDark,
          onAiChat:       () => showDashSheet(context),
          onReport:       () => _push(_Screen.reportProblem),
          onTickets:      () => _push(_Screen.myTickets),
          onStatus:       () => _push(_Screen.systemStatus),
          onEmergency:    () => _push(_Screen.emergency),
          onFaqCategory:  (cat) { _activeFaqCategory = cat; _push(_Screen.faqCategory); },
          onService:      (svc) { _activeService = svc; _push(_Screen.serviceHelp); },
        );
    }
  }
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class _MainScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onAiChat, onReport, onTickets, onStatus, onEmergency;
  final void Function(FaqCategory) onFaqCategory;
  final void Function(_ServiceCategory) onService;
  const _MainScreen({required this.isDark, required this.onAiChat, required this.onReport,
    required this.onTickets, required this.onStatus, required this.onEmergency,
    required this.onFaqCategory, required this.onService});
  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> {
  final _searchCtrl = TextEditingController();
  List<FaqItem> _searchResults = [];
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final creds = await getIt<OtpAuthService>().getStoredCredentials();
    if (!mounted) return;
    final raw   = creds?['username'] ?? '';
    final alias = creds?['alias'];
    setState(() => _userName = alias?.isNotEmpty == true ? alias! : (raw.isNotEmpty ? raw : 'there'));
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) { setState(() => _searchResults = []); return; }
    final results = <FaqItem>[];
    for (final cat in faqData) {
      for (final item in cat.items) {
        if (item.question.toLowerCase().contains(q) || item.answer.toLowerCase().contains(q)) {
          results.add(item);
        }
      }
    }
    setState(() => _searchResults = results);
  }

  Color _bg(bool isDark)      => isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA);
  Color _card(bool isDark)    => isDark ? const Color(0xFF161B22) : Colors.white;
  Color _text(bool isDark)    => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color _sub(bool isDark)     => isDark ? Colors.white54 : Colors.black54;
  Color _border(bool isDark)  => isDark ? Colors.white12 : Colors.black12;

  @override
  Widget build(BuildContext context) {
    final d = widget.isDark;
    return Scaffold(
      backgroundColor: _bg(d),
      appBar: AppBar(
        backgroundColor: _card(d),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: _text(d), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Help & Support', style: TextStyle(color: _text(d), fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: _text(d)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(d),
            _buildSearchBar(d),
            if (_searchResults.isNotEmpty) _buildSearchResults(d) else ...[
              _buildQuickActions(d),
              _buildBrowseByService(d),
              _buildFaqSection(d),
              _buildSystemStatusPreview(d),
              _buildEmergencyBanner(d),
              _buildContactMethods(d),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(bool d) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card(d),
        border: Border(bottom: BorderSide(color: _border(d))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('👋 ', style: const TextStyle(fontSize: 28)),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi $_userName,', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _text(d))),
                const SizedBox(height: 2),
                Text('How can we help you today?', style: TextStyle(fontSize: 14, color: _sub(d))),
              ],
            )),
          ]),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool d) {
    return Container(
      color: _card(d),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search help...',
              hintStyle: TextStyle(color: _sub(d), fontSize: 15),
              prefixIcon: Icon(Icons.search, color: _sub(d)),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: Icon(Icons.clear, color: _sub(d)), onPressed: () { _searchCtrl.clear(); })
                  : null,
              filled: true,
              fillColor: d ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF0F3FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(color: _text(d)),
          ),
          if (_searchCtrl.text.isEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ['Payment failed', 'Buy airtime', 'Order tracking', 'Forgot PIN', 'ZESA token']
                .map((s) => GestureDetector(
                  onTap: () => _searchCtrl.text = s,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: d ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8EEFF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: d ? Colors.white12 : const Color(0xFFBBC8F5)),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 12, color: d ? Colors.white70 : const Color(0xFF3558CD))),
                  ),
                )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool d) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'}',
              style: TextStyle(color: _sub(d), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          ..._searchResults.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: _card(d), borderRadius: BorderRadius.circular(14),
                boxShadow: [if (!d) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
            child: ExpansionTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFF185FA5), size: 22),
              title: Text(item.question, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text(d))),
              children: [Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(item.answer, style: TextStyle(fontSize: 13, color: _sub(d), height: 1.5)),
              )],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool d) {
    final actions = [
      (icon: Icons.chat_bubble_outline, label: 'Chat with\nSupport', sub: 'Avg < 2 min', color: const Color(0xFF185FA5),
        onTap: () => _launchUrl(_kSupportPhone)),
      (icon: Icons.smart_toy_outlined,  label: 'Ask Dash',   sub: 'Instant answers', color: const Color(0xFF9C27B0),
        onTap: widget.onAiChat),
      (icon: Icons.chat_bubble_outline,            label: 'WhatsApp\nSupport',  sub: '24/7 available', color: const Color(0xFF25D366),
        onTap: () => openWhatsAppSupport(context, _userName)),
      (icon: Icons.phone_outlined,      label: 'Request\na Call',    sub: 'Business hours', color: const Color(0xFF00BCD4),
        onTap: () => _launchUrl(_kSupportPhone)),
      (icon: Icons.email_outlined,      label: 'Email\nSupport',     sub: 'Reply < 24 hrs', color: const Color(0xFFFF9800),
        onTap: () => _launchUrl('mailto:$_kSupportEmail')),
      (icon: Icons.confirmation_number_outlined, label: 'Track My\nTickets', sub: 'View all requests', color: const Color(0xFF4CAF50),
        onTap: widget.onTickets),
    ];

    return _Section(
      title: 'Quick Actions',
      isDark: d,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
        padding: EdgeInsets.zero,
        children: actions.map((a) => _QuickActionCard(
          icon: a.icon, label: a.label, sub: a.sub, color: a.color, isDark: d, onTap: a.onTap,
        )).toList(),
      ),
    );
  }

  Widget _buildBrowseByService(bool d) {
    return _Section(
      title: 'Browse by Service',
      isDark: d,
      child: Column(
        children: _serviceData.map((svc) => _ServiceRow(
          service: svc, isDark: d, onTap: () => widget.onService(svc),
        )).toList(),
      ),
    );
  }

  Widget _buildFaqSection(bool d) {
    return _Section(
      title: 'Frequently Asked Questions',
      isDark: d,
      child: Column(
        children: faqData.map((cat) => _buildFaqCategoryRow(cat, d)).toList(),
      ),
    );
  }

  Widget _buildFaqCategoryRow(FaqCategory cat, bool d) {
    return GestureDetector(
      onTap: () => widget.onFaqCategory(cat),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: d ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: d ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(cat.icon, color: cat.color, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Text(cat.title, style: TextStyle(fontWeight: FontWeight.w600, color: d ? Colors.white : Colors.black87))),
          Text('${cat.items.length} topics', style: TextStyle(fontSize: 12, color: _sub(d))),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: _sub(d), size: 20),
        ]),
      ),
    );
  }

  Widget _buildSystemStatusPreview(bool d) {
    final allGood = _systemServices.every((s) => s.status == _ServiceStatus.operational);
    return _Section(
      title: 'System Status',
      isDark: d,
      action: _TextButton(label: 'View All', isDark: d, onTap: widget.onStatus),
      child: GestureDetector(
        onTap: widget.onStatus,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: allGood
                ? const Color(0xFF4CAF50).withValues(alpha: d ? 0.15 : 0.08)
                : const Color(0xFFE53935).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: allGood ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : const Color(0xFFE53935).withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(
              color: allGood ? const Color(0xFF4CAF50).withValues(alpha: 0.15) : const Color(0xFFE53935).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ), child: Icon(allGood ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                color: allGood ? const Color(0xFF4CAF50) : const Color(0xFFE53935), size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(allGood ? 'All Systems Operational' : 'Some Services Degraded',
                  style: TextStyle(fontWeight: FontWeight.bold, color: d ? Colors.white : Colors.black87)),
              const SizedBox(height: 2),
              Text(allGood ? '${_systemServices.length} services running normally' : 'Tap to see details',
                  style: TextStyle(fontSize: 12, color: _sub(d))),
            ])),
            Icon(Icons.chevron_right, color: _sub(d)),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmergencyBanner(bool d) {
    return _Section(
      title: 'Emergency',
      isDark: d,
      child: GestureDetector(
        onTap: widget.onEmergency,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: d
                  ? [const Color(0xFF4A0000), const Color(0xFF2D0000)]
                  : [const Color(0xFFFFEBEE), const Color(0xFFFCE4EC)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: const Color(0xFFE53935).withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.emergency_outlined, color: Color(0xFFE53935), size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Account compromised or lost device?', style: TextStyle(fontWeight: FontWeight.bold,
                  color: d ? Colors.white : Colors.red.shade900, fontSize: 13)),
              const SizedBox(height: 2),
              Text('Freeze account, report fraud & more', style: TextStyle(fontSize: 12,
                  color: d ? Colors.white60 : Colors.red.shade700)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(20)),
                child: const Text('Act Now', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
        ),
      ),
    );
  }

  Widget _buildContactMethods(bool d) {
    final methods = [
      (icon: Icons.chat_bubble_outline,         label: 'WhatsApp',  color: const Color(0xFF25D366), onTap: () => openWhatsAppSupport(context, _userName)),
      (icon: Icons.chat_outlined,    label: 'Live Chat', color: const Color(0xFF185FA5), onTap: widget.onAiChat),
      (icon: Icons.phone_outlined,   label: 'Call',      color: const Color(0xFF00BCD4), onTap: () => _launchUrl(_kSupportPhone)),
      (icon: Icons.email_outlined,   label: 'Email',     color: const Color(0xFFFF9800), onTap: () => _launchUrl('mailto:$_kSupportEmail')),
      (icon: Icons.telegram,         label: 'Telegram',  color: const Color(0xFF2AABEE), onTap: () => _launchUrl('https://t.me/firststreet')),
      (icon: Icons.language_outlined,label: 'Website',   color: const Color(0xFF607D8B), onTap: () => _launchUrl(_kWebsite)),
    ];

    return _Section(
      title: 'Contact Us',
      isDark: d,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: methods.map((m) => _ContactChip(icon: m.icon, label: m.label, color: m.color, isDark: d, onTap: m.onTap)).toList(),
      ),
    );
  }
}

// ─── Report a Problem Screen ──────────────────────────────────────────────────

class _ReportProblemScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onBack;
  const _ReportProblemScreen({required this.isDark, required this.onBack});
  @override
  State<_ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<_ReportProblemScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _issueCtrl = TextEditingController();
  int _serviceIdx = -1;
  bool _submitting = false;
  bool _submitted  = false;

  final _services = ['Calling & Airtime', 'Shopping', 'Utility Bills', 'Wallet', 'Payments', 'Account', 'Other'];

  @override
  void dispose() { _issueCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_serviceIdx == -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a service')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() { _submitting = false; _submitted = true; });
  }

  Color _card(bool d) => d ? const Color(0xFF161B22) : Colors.white;
  Color _text(bool d) => d ? Colors.white : const Color(0xFF1A1A2E);
  Color _sub(bool d)  => d ? Colors.white54 : Colors.black54;

  @override
  Widget build(BuildContext context) {
    final d = widget.isDark;
    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _card(d), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: _text(d), size: 20), onPressed: widget.onBack),
        title: Text('Report a Problem', style: TextStyle(color: _text(d), fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: _submitted ? _buildSuccess(d) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionHeader(title: 'Select Service', isDark: d),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: List.generate(_services.length, (i) => ChoiceChip(
                label: Text(_services[i]),
                selected: _serviceIdx == i,
                onSelected: (_) => setState(() => _serviceIdx = i),
                selectedColor: const Color(0xFF185FA5),
                labelStyle: TextStyle(color: _serviceIdx == i ? Colors.white : _sub(d), fontSize: 13),
                backgroundColor: d ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF0F3FA),
                side: BorderSide(color: _serviceIdx == i ? const Color(0xFF185FA5) : Colors.transparent),
              )),
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: 'Describe Your Issue', isDark: d),
            const SizedBox(height: 10),
            TextFormField(
              controller: _issueCtrl, maxLines: 5, style: TextStyle(color: _text(d)),
              decoration: InputDecoration(
                hintText: 'Tell us what happened in detail...',
                hintStyle: TextStyle(color: _sub(d)),
                filled: true,
                fillColor: d ? Colors.white.withValues(alpha: 0.07) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: d ? Colors.white12 : Colors.black12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: d ? Colors.white12 : Colors.black12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF185FA5), width: 2)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please describe your issue' : null,
            ),
            const SizedBox(height: 20),
            _buildAttachmentRow(d),
            const SizedBox(height: 24),
            _buildAutoInfo(d),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAttachmentRow(bool d) {
    return Row(children: [
      _AttachBtn(icon: Icons.image_outlined,   label: 'Screenshot', isDark: d),
      const SizedBox(width: 10),
      _AttachBtn(icon: Icons.receipt_outlined, label: 'Receipt',    isDark: d),
      const SizedBox(width: 10),
      _AttachBtn(icon: Icons.attach_file,      label: 'File',       isDark: d),
    ]);
  }

  Widget _buildAutoInfo(bool d) {
    final os = Platform.operatingSystem.capitalize();
    final osVer = Platform.operatingSystemVersion.split(' ').take(2).join(' ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: d ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: d ? Colors.white10 : const Color(0xFFBBC8F5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF185FA5)),
          const SizedBox(width: 8),
          Text('Auto-attached diagnostics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: d ? Colors.white70 : const Color(0xFF185FA5))),
        ]),
        const SizedBox(height: 8),
        _InfoRow(label: 'App Version', value: _kAppVersion, isDark: d),
        _InfoRow(label: 'OS',         value: '$os $osVer',  isDark: d),
        _InfoRow(label: 'Device',     value: Platform.localHostname, isDark: d),
        _InfoRow(label: 'Timestamp',  value: DateTime.now().toLocal().toString().split('.').first, isDark: d),
      ]),
    );
  }

  Widget _buildSuccess(bool d) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 40, color: Colors.white)),
        const SizedBox(height: 24),
        Text('Report Submitted', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: d ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        Text('We have received your report and will respond within 24 hours. You can track progress in My Tickets.',
            textAlign: TextAlign.center, style: TextStyle(color: d ? Colors.white54 : Colors.black54, height: 1.5)),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, height: 50, child: OutlinedButton(
          onPressed: widget.onBack,
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF185FA5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Back to Help', style: TextStyle(color: Color(0xFF185FA5), fontWeight: FontWeight.w600)),
        )),
      ]),
    ));
  }
}

// ─── My Tickets Screen ────────────────────────────────────────────────────────

class _MyTicketsScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  final List<_Ticket> tickets;
  final void Function(_Ticket) onTap;
  const _MyTicketsScreen({required this.isDark, required this.onBack, required this.tickets, required this.onTap});

  Color _card(bool d) => d ? const Color(0xFF161B22) : Colors.white;
  Color _text(bool d) => d ? Colors.white : const Color(0xFF1A1A2E);
  Color _sub(bool d)  => d ? Colors.white54 : Colors.black54;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _card(isDark), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: _text(isDark), size: 20), onPressed: onBack),
        title: Text('My Requests', style: TextStyle(color: _text(isDark), fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: tickets.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.inbox_outlined, size: 64, color: _sub(isDark)),
              const SizedBox(height: 16),
              Text('No support tickets yet', style: TextStyle(color: _sub(isDark), fontSize: 16)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TicketCard(ticket: tickets[i], isDark: isDark, onTap: () => onTap(tickets[i])),
            ),
    );
  }
}

class _TicketDetailScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  final _Ticket ticket;
  const _TicketDetailScreen({required this.isDark, required this.onBack, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final d = isDark;
    final (color, label, icon) = _ticketStatusMeta(ticket.status);
    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: d ? const Color(0xFF161B22) : Colors.white, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: d ? Colors.white : Colors.black87, size: 20), onPressed: onBack),
        title: Text(ticket.id, style: TextStyle(color: d ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: d ? const Color(0xFF161B22) : Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(ticket.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: d ? Colors.white : Colors.black87))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  ])),
            ]),
            const SizedBox(height: 8),
            Text('Category: ${ticket.category}', style: TextStyle(fontSize: 13, color: d ? Colors.white54 : Colors.black54)),
            Text('Updated: ${_formatDate(ticket.updatedAt)}', style: TextStyle(fontSize: 13, color: d ? Colors.white54 : Colors.black54)),
          ]),
        ),
        const SizedBox(height: 20),
        Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: d ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        _TimelineItem(label: 'Ticket created', sub: _formatDate(ticket.updatedAt.subtract(const Duration(hours: 2))), isDark: d, done: true),
        _TimelineItem(label: 'Assigned to support team', sub: _formatDate(ticket.updatedAt.subtract(const Duration(hours: 1))), isDark: d, done: true),
        _TimelineItem(label: ticket.status == _TicketStatus.resolved ? 'Issue resolved' : 'Under investigation', sub: _formatDate(ticket.updatedAt), isDark: d, done: ticket.status == _TicketStatus.resolved, isLast: true),
        const SizedBox(height: 24),
        if (ticket.status != _TicketStatus.resolved) SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF185FA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: const Text('Add Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          )),
        if (ticket.status == _TicketStatus.resolved) _RatingWidget(isDark: d),
      ]),
    );
  }
}

// ─── System Status Screen ─────────────────────────────────────────────────────

class _SystemStatusScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  const _SystemStatusScreen({required this.isDark, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final d = isDark;
    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: d ? const Color(0xFF161B22) : Colors.white, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: d ? Colors.white : Colors.black87, size: 20), onPressed: onBack),
        title: Text('System Status', style: TextStyle(color: d ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF185FA5)), onPressed: () {})],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: d ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('All Systems Operational', style: TextStyle(fontWeight: FontWeight.bold, color: d ? Colors.white : Colors.black87)),
              Text('Last checked: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 12, color: d ? Colors.white54 : Colors.black54)),
            ]),
          ]),
        ),
        ..._systemServices.map((svc) {
          final (color, label, _) = _statusMeta(svc.status);
          return Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: d ? const Color(0xFF161B22) : Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: const Color(0xFF185FA5).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(svc.icon, color: const Color(0xFF185FA5), size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Text(svc.name, style: TextStyle(fontWeight: FontWeight.w600, color: d ? Colors.white : Colors.black87))),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ─── Emergency Screen ─────────────────────────────────────────────────────────

class _EmergencyScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  const _EmergencyScreen({required this.isDark, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final d = isDark;
    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: d ? const Color(0xFF161B22) : Colors.white, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: d ? Colors.white : Colors.black87, size: 20), onPressed: onBack),
        title: Text('Emergency', style: TextStyle(color: const Color(0xFFE53935), fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFE53935).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.warning_amber_outlined, color: Color(0xFFE53935), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text('Select the appropriate action below. Your account may be temporarily restricted to protect your funds.',
                style: TextStyle(fontSize: 13, color: d ? Colors.white70 : Colors.black87, height: 1.4))),
          ]),
        ),
        ..._emergencyActions.map((a) => _EmergencyCard(icon: a.icon, label: a.label, subtitle: a.subtitle, color: a.color, isDark: d)),
        const SizedBox(height: 24),
        Center(child: TextButton.icon(
          onPressed: () => _launchUrl(_kSupportPhone),
          icon: const Icon(Icons.phone_outlined, color: Color(0xFFE53935)),
          label: const Text('Call Emergency Support Line', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
        )),
      ]),
    );
  }
}

// ─── FAQ Category Screen ──────────────────────────────────────────────────────

class _FaqCategoryScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  final FaqCategory category;
  const _FaqCategoryScreen({required this.isDark, required this.onBack, required this.category});

  Color _card(bool d) => d ? const Color(0xFF161B22) : Colors.white;
  Color _text(bool d) => d ? Colors.white : const Color(0xFF1A1A2E);
  Color _sub(bool d)  => d ? Colors.white54 : Colors.black54;

  @override
  Widget build(BuildContext context) {
    final d = isDark;
    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _card(d), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: _text(d), size: 20), onPressed: onBack),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(category.icon, color: category.color, size: 20),
          const SizedBox(width: 8),
          Text(category.title, style: TextStyle(color: _text(d), fontWeight: FontWeight.w600, fontSize: 18)),
        ]),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: category.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final item = category.items[i];
          return Container(
            decoration: BoxDecoration(color: _card(d), borderRadius: BorderRadius.circular(14),
                boxShadow: [if (!d) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
            child: ExpansionTile(
              leading: Container(width: 34, height: 34,
                  decoration: BoxDecoration(color: category.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.help_outline, color: category.color, size: 18)),
              title: Text(item.question, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _text(d))),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [Text(item.answer, style: TextStyle(fontSize: 13, color: _sub(d), height: 1.6))],
            ),
          );
        },
      ),
    );
  }
}

// ─── Service Help Screen ──────────────────────────────────────────────────────

class _ServiceHelpScreen extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  final _ServiceCategory service;
  final void Function(FaqCategory) onFaqTap;
  const _ServiceHelpScreen({required this.isDark, required this.onBack, required this.service, required this.onFaqTap});

  @override
  Widget build(BuildContext context) {
    final d = isDark;
    // Find matching FAQ category
    final faqCat = faqData.where((c) => c.title.toLowerCase().contains(service.name.toLowerCase().split(' ').first)).firstOrNull;

    return Scaffold(
      backgroundColor: d ? const Color(0xFF0D1117) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: d ? const Color(0xFF161B22) : Colors.white, elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: d ? Colors.white : Colors.black87, size: 20), onPressed: onBack),
        title: Text('${service.name} Help', style: TextStyle(color: d ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 10, runSpacing: 10, children: service.topics.map((t) => _TopicChip(topic: t, service: service, isDark: d)).toList()),
        if (faqCat != null) ...[
          const SizedBox(height: 24),
          Text('Related Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: d ? Colors.white : Colors.black87)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => onFaqTap(faqCat),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: service.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: service.color.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(faqCat.icon, color: service.color, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text('View all ${service.name} FAQs', style: TextStyle(fontWeight: FontWeight.w600, color: d ? Colors.white : Colors.black87))),
                Icon(Icons.arrow_forward_ios, size: 14, color: service.color),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Reusable small widgets ───────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final bool isDark;
  final Widget child;
  final Widget? action;
  const _Section({required this.title, required this.isDark, required this.child, this.action});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
          if (action != null) action!,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});
  @override
  Widget build(BuildContext context) => Text(title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87));
}

class _TextButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _TextButton({required this.label, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF185FA5), fontWeight: FontWeight.w600)));
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _QuickActionCard({required this.icon, required this.label, required this.sub, required this.color, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: d ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: d ? 0.25 : 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: d ? Colors.white : Colors.black87, height: 1.3)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10, color: d ? Colors.white38 : Colors.black38)),
          ]),
        ]),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final _ServiceCategory service;
  final bool isDark;
  final VoidCallback onTap;
  const _ServiceRow({required this.service, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: d ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: d ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: service.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(service.icon, color: service.color, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(service.name, style: TextStyle(fontWeight: FontWeight.w700, color: d ? Colors.white : Colors.black87))),
            Icon(Icons.chevron_right, color: d ? Colors.white38 : Colors.black38, size: 20),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: service.topics.take(4).map((t) =>
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: service.color.withValues(alpha: d ? 0.1 : 0.07), borderRadius: BorderRadius.circular(20)),
                  child: Text(t.label, style: TextStyle(fontSize: 11, color: service.color, fontWeight: FontWeight.w500)))).toList()),
        ]),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _ContactChip({required this.icon, required this.label, required this.color, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(width: 48, height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)),
      ]),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final _Ticket ticket;
  final bool isDark;
  final VoidCallback onTap;
  const _TicketCard({required this.ticket, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    final (color, label, icon) = _ticketStatusMeta(ticket.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: d ? const Color(0xFF161B22) : Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: d ? Colors.white10 : Colors.black.withValues(alpha: 0.06))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ticket.id, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF185FA5))),
            const SizedBox(height: 4),
            Text(ticket.title, style: TextStyle(fontWeight: FontWeight.w600, color: d ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(_formatDate(ticket.updatedAt), style: TextStyle(fontSize: 12, color: d ? Colors.white38 : Colors.black38)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ])),
        ]),
      ),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final bool isDark;
  const _EmergencyCard({required this.icon, required this.label, required this.subtitle, required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final d = isDark;
    return GestureDetector(
      onTap: () => _showEmergencyConfirm(context, label, d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: d ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: d ? Colors.white : Colors.black87)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: d ? Colors.white54 : Colors.black54)),
          ])),
          Icon(Icons.chevron_right, color: color, size: 20),
        ]),
      ),
    );
  }
}

class _AttachBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _AttachBtn({required this.icon, required this.label, required this.isDark});
  @override
  Widget build(BuildContext context) => Expanded(
    child: OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : Colors.black54,
        side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool isDark;
  const _InfoRow({required this.label, required this.value, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 96, child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))),
    ]),
  );
}

class _TimelineItem extends StatelessWidget {
  final String label, sub;
  final bool isDark, done;
  final bool isLast;
  const _TimelineItem({required this.label, required this.sub, required this.isDark, required this.done, this.isLast = false});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Column(children: [
      Container(width: 22, height: 22, decoration: BoxDecoration(color: done ? const Color(0xFF4CAF50) : Colors.grey.shade400, shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.white, size: 14)),
      if (!isLast) Container(width: 2, height: 40, color: done ? const Color(0xFF4CAF50).withValues(alpha: 0.3) : Colors.grey.shade300),
    ]),
    const SizedBox(width: 14),
    Expanded(child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        Text(sub, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
      ]),
    )),
  ]);
}

class _RatingWidget extends StatefulWidget {
  final bool isDark;
  const _RatingWidget({required this.isDark});
  @override
  State<_RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<_RatingWidget> {
  int _stars = 0;
  bool _resolved = false;
  bool _submitted = false;
  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('Thank you for your feedback! 🙏', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w600))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF161B22) : const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text('Rate your support experience', style: TextStyle(fontWeight: FontWeight.w600, color: widget.isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => GestureDetector(
          onTap: () => setState(() => _stars = i + 1),
          child: Icon(i < _stars ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
        ))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _resolved
              ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20)
              : GestureDetector(onTap: () => setState(() => _resolved = true), child: const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 20)),
          const SizedBox(width: 8),
          Text('Issue resolved', style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black87)),
        ]),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _stars == 0 ? null : () => setState(() => _submitted = true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF185FA5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
          child: const Text('Submit Feedback', style: TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final _ServiceTopic topic;
  final _ServiceCategory service;
  final bool isDark;
  const _TopicChip({required this.topic, required this.service, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? service.color.withValues(alpha: 0.12) : service.color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: service.color.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(topic.icon, size: 16, color: service.color),
      const SizedBox(width: 8),
      Text(topic.label, style: TextStyle(fontSize: 13, color: service.color, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─── Utility functions ────────────────────────────────────────────────────────

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
}

Future<void> openWhatsAppSupport(BuildContext context, String userName) async {
  final creds = await getIt<OtpAuthService>().getStoredCredentials();
  final phone  = creds?['username'] ?? '';
  final os     = Platform.operatingSystem;
  final osVer  = Platform.operatingSystemVersion.split(' ').take(2).join(' ');
  final device = Platform.localHostname;

  final msg = '''Hello First Street Support 👋

I need assistance with:
☐ Calling   ☐ Shopping   ☐ Utility Bills
☐ Wallet    ☐ Payments   ☐ Account   ☐ Other

📋 My Details
Username: $userName
Phone: $phone
App Version: $_kAppVersion
OS: $os $osVer
Device: $device
Time: ${DateTime.now().toLocal().toString().split('.').first}

📝 Issue:
______________________________''';

  final url = Uri.parse('https://wa.me/$_kWhatsAppNumber?text=${Uri.encodeComponent(msg)}');
  if (await canLaunchUrl(url)) { await launchUrl(url, mode: LaunchMode.externalApplication); }
}

void _showEmergencyConfirm(BuildContext context, String action, bool isDark) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      title: Text('Confirm: $action', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      content: Text('This action will immediately affect your account. Continue?', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _launchUrl('tel:+$_kWhatsAppNumber'); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), elevation: 0),
          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

(Color, String, IconData) _ticketStatusMeta(_TicketStatus s) => switch (s) {
  _TicketStatus.open       => (const Color(0xFF185FA5), 'Open',        Icons.fiber_new),
  _TicketStatus.inProgress => (const Color(0xFFFF9800), 'In Progress', Icons.pending_outlined),
  _TicketStatus.resolved   => (const Color(0xFF4CAF50), 'Resolved',    Icons.check_circle_outline),
};

(Color, String, IconData) _statusMeta(_ServiceStatus s) => switch (s) {
  _ServiceStatus.operational => (const Color(0xFF4CAF50), 'Operational', Icons.check_circle),
  _ServiceStatus.degraded    => (const Color(0xFFFF9800), 'Degraded',    Icons.warning_amber),
  _ServiceStatus.outage      => (const Color(0xFFE53935), 'Outage',      Icons.cancel),
};

String _formatDate(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ignore: unused_element
extension _CapExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
