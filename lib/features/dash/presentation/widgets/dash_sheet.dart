import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme.dart';
import '../../../account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import '../../../help_support/presentation/views/help_support_view.dart'
    show openWhatsAppSupport;
import '../viewmodels/dash_viewmodel.dart';

const _dashChips = [
  'Check data balance',
  'How do I top up?',
  'Bundle prices',
  'Talk to a human',
];

Future<void> showDashSheet(BuildContext context) {
  context.read<DashViewModel>().dismissNudge();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const DashSheet(),
  );
}

class DashSheet extends StatefulWidget {
  const DashSheet({super.key});

  @override
  State<DashSheet> createState() => _DashSheetState();
}

class _DashSheetState extends State<DashSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit(String text) async {
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    final dashVm = context.read<DashViewModel>();
    final userName = context.read<AccountSummaryViewModel>().alias ?? 'there';

    await dashVm.submit(text);
    if (!mounted) return;

    if (dashVm.consumeEscalation()) {
      await openWhatsAppSupport(context, userName);
    }
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashVm = context.watch<DashViewModel>();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: dashVm.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            dashVm.messages.length + (dashVm.thinking ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == dashVm.messages.length) {
                            return const _DashThinkingBubble();
                          }
                          final m = dashVm.messages[i];
                          return _DashChatBubble(text: m.text, isUser: m.isUser);
                        },
                      ),
              ),
              _buildChips(),
              _buildInput(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Dash is an AI assistant and can make mistakes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: WunzaColors.glidePrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: WunzaColors.glidePrimary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dash',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Online · usually replies instantly',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        "Hi! I'm Dash 👋 I can help with balances, bundles, billing questions "
        "and more. What do you need?",
        style: TextStyle(fontSize: 14, height: 1.4),
      ),
    );
  }

  Widget _buildChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _dashChips
            .map((label) => ActionChip(
                  label: Text(label),
                  onPressed: () => _submit(label),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Ask Dash anything...',
                filled: true,
                fillColor: const Color(0xFFF4F6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _submit(_ctrl.text),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: WunzaColors.glidePrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  const _DashChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? WunzaColors.glidePrimary : const Color(0xFFF0F3FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 18 : 4),
                  topRight: Radius.circular(isUser ? 4 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashThinkingBubble extends StatelessWidget {
  const _DashThinkingBubble();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3FA),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: WunzaColors.glidePrimary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
