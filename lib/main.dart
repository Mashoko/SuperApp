import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';

import 'core/di/inject.dart';
import 'core/managers/sip_call_manager.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'features/auth/presentation/viewmodels/auth_viewmodel.dart';

import 'features/call/presentation/views/call_view.dart';
import 'features/call/presentation/viewmodels/call_viewmodel.dart';
import 'features/calling/presentation/views/calling_view.dart';
import 'features/calling/presentation/viewmodels/calling_viewmodel.dart';
import 'features/dialpad/presentation/viewmodels/dialpad_viewmodel.dart';


import 'features/dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import 'features/shopping/presentation/viewmodels/shopping_viewmodel.dart';
import 'features/utility_bills/presentation/viewmodels/utility_bills_viewmodel.dart';
import 'features/account_summary/presentation/viewmodels/account_summary_viewmodel.dart';
import 'shared/theme/theme_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Logger.level = Level.warning;
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }

  // Initialize dependency injection
  await configureDependencies();

  // Initialize SipCallManager
  final sipHelper = getIt<SIPUAHelper>();
  // ignore: unused_local_variable
  final sipCallManager = SipCallManager(
    sipHelper, 
    navigatorKey, 
    getIt<DialpadViewModel>(),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get dependencies (ensure they are registered in injected.dart)
    final themeProvider = getIt<ThemeProvider>();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => getIt<DashboardViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<ShoppingViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<UtilityBillsViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<AuthViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<CallingViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<DialpadViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<AccountSummaryViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<CallViewModel>()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Super App',
            debugShowCheckedModeBanner: false,
        
            // For now, forcing WunzaTheme to ensure source look as requested
            theme: WunzaTheme.lightTheme, 
            initialRoute: Routes.root,
            routes: Routes.routes,
            onGenerateRoute: (settings) {
              if (settings.name == Routes.calling) {
                 final args = settings.arguments;
                 if (args is Call) {
                   return MaterialPageRoute(
                     builder: (context) => CallView(call: args),
                   );
                 } else if (args is int) {
                   return MaterialPageRoute(
                     builder: (context) => CallingView(initialIndex: args),
                   );
                 }
                 // Default fallback if no args or invalid args
                 return MaterialPageRoute(
                   builder: (context) => const CallingView(),
                 );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
