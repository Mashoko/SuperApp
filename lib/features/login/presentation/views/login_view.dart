import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/routes.dart';

import '../../../../core/di/inject.dart';
import '../viewmodels/login_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late LoginViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<LoginViewModel>();
    _viewModel.checkAutoLogin().then((summary) {
      if (summary != null && mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: summary,
        );
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>.value(
      value: _viewModel,
      child: Consumer<LoginViewModel>(
        builder: (context, viewModel, _) {
          final loading = viewModel.loading;
          final error = viewModel.error;

          return Scaffold(
            appBar: AppBar(title: const Text('Login')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter your username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading
                          ? null
                          : () async {
                              final summary = await viewModel.login(
                                _usernameController.text,
                                _passwordController.text,
                              );
                              if (!mounted) return;
                              if (summary != null) {
                                if (!context.mounted) return;
                                Navigator.pushReplacementNamed(
                                  context,
                                  Routes.home,
                                  arguments: summary,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: loading 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.registration);
                    },
                    child: const Text('New User? Register with OTP'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
