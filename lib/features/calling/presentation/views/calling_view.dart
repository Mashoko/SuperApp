import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/viewmodels/calling_viewmodel.dart';
import 'package:mvvm_sip_demo/features/contacts/presentation/views/contacts_view.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/views/tabs/dialer_view.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/views/tabs/recents_view.dart';
import 'package:mvvm_sip_demo/features/calling/presentation/views/tabs/speed_test_view.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';

class CallingView extends StatefulWidget {
  final int initialIndex;
  const CallingView({super.key, this.initialIndex = 0});

  @override
  State<CallingView> createState() => _CallingViewState();
}

class _CallingViewState extends State<CallingView> {
  int _currentIndex = 0;
  late PageController _pageController;

  final List<Widget> _tabs = [
     const DialerView(),
     const RecentsView(),
     const ContactsView(), // Replaced AccountServicesView with ContactsView
     const SpeedTestView(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadData() {
    final viewModel = Provider.of<CallingViewModel>(context, listen: false);
    viewModel.loadActiveCalls();
    viewModel.loadCallHistory();
  }

  void _onTabTapped(int index) {
    if (index == 4) {
      // Home selected
      Navigator.pop(context);
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // --- Background Gradient & Blobs (Matches HomeView) ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE0E7FF), // Very light Indigo
                  Color(0xFFF3F4F6), // Grey/White
                ],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.indigo.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: WunzaColors.blueAccent.withValues(alpha: 0.15),
              ),
            ),
          ),

          // --- Main Content ---
          SafeArea(
            bottom: false,
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: GlassContainer(
          borderRadius: 30,
          blur: 20,
          opacity: 0.7,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: NavigationBar(
            height: 60,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            indicatorColor: WunzaColors.indigo.withValues(alpha: 0.2),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.phone_outlined),
                selectedIcon: Icon(Icons.phone, color: WunzaColors.indigo),
                label: 'Phone',
              ),
              NavigationDestination(
                icon: Icon(Icons.access_time_outlined),
                selectedIcon: Icon(Icons.access_time_filled, color: WunzaColors.blueAccent),
                label: 'Recents',
              ),
              NavigationDestination(
                icon: Icon(Icons.contacts_outlined),
                selectedIcon: Icon(Icons.contacts, color: WunzaColors.orangeAccent),
                label: 'Contacts',
              ),
              NavigationDestination(
                icon: Icon(Icons.speed_outlined),
                selectedIcon: Icon(Icons.speed, color: WunzaColors.greenAccent),
                label: 'Speed Test',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: WunzaColors.indigo),
                label: 'Home',
              ),
            ],
          ),
        ),
      ),
    );
  }
}


