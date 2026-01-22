import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'users_client.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/call_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<UsersClient>(
          create: (_) => UsersClient(
            packageId: 'org.africom.catchapp',
            secure: false,
          ),
          dispose: (_, client) => client.close(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            usersClient: context.read<UsersClient>(),
          ),
        ),
        ChangeNotifierProvider<CallViewModel>(
          create: (context) => CallViewModel(
            usersClient: context.read<UsersClient>(),
          ),
        ),
      ],
      child: const CatchCallApp(),
    ),
  );
}

