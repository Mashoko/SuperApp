import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import '../viewmodels/registration_viewmodel.dart';
import '../../../../core/routes.dart';
import '../../../../core/di/inject.dart';
import 'package:mvvm_sip_demo/core/theme.dart';
import 'package:mvvm_sip_demo/shared/widgets/glass_container.dart';

class RegistrationView extends StatefulWidget {
  const RegistrationView({super.key});

  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView>
    implements SipUaHelperListener {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  late RegistrationViewModel _viewModel;
  late SIPUAHelper _sipHelper;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<RegistrationViewModel>();
    _sipHelper = getIt<SIPUAHelper>();
    _sipHelper.addSipUaHelperListener(this);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _sipHelper.removeSipUaHelperListener(this);
    super.dispose();
  }

  void _alert(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Alert'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<RegistrationViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Registration"),
              leading: viewModel.currentStep == RegistrationStep.otpInput
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: viewModel.reset,
                    )
                  : null,
            ),
            body: Stack(
              children: [
                 // Global Background
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE0E7FF), Color(0xFFF3F4F6)],
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

                // Content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: GlassContainer(
                      opacity: 0.9,
                      borderRadius: 24,
                      child: _buildCurrentStep(viewModel),
                    ),
                  ),
                ),
              ],
             ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStep(RegistrationViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (viewModel.currentStep) {
      case RegistrationStep.phoneInput:
        return _buildPhoneInputStep(viewModel);
      case RegistrationStep.otpInput:
        return _buildOtpInputStep(viewModel);
      case RegistrationStep.registering:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Setting up your account..."),
            ],
          ),
        );
      case RegistrationStep.completed:
        return _buildCompletedStep(viewModel);
    }
  }

  Widget _buildPhoneInputStep(RegistrationViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Enter your mobile number",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "We will send you a verification code via WhatsApp.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Phone Number",
            hintText: "e.g. 0771234567",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        if (viewModel.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              viewModel.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            final phone = _phoneController.text.trim();
            if (phone.isNotEmpty) {
              viewModel.sendOtp(phone);
            } else {
              _alert(context, "Please enter a phone number");
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: const Text("Send Verification Code"),
        ),
      ],
    );
  }

  Widget _buildOtpInputStep(RegistrationViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Enter Verification Code",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          "Enter the code sent to your WhatsApp.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "OTP Code",
            hintText: "Enter 6-digit code",
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
        ),
        if (viewModel.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              viewModel.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            final otp = _otpController.text.trim();
            if (otp.isNotEmpty) {
              viewModel.verifyOtp(otp);
            } else {
              _alert(context, "Please enter the OTP");
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: const Text("Verify & Register"),
        ),
      ],
    );
  }

  Widget _buildCompletedStep(RegistrationViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          const Text(
            "Registration Successful!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "SIP Account: ${viewModel.currentUser?.sipUri ?? ''}",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 10),
          Text(
            "Status: ${viewModel.registrationState?.state?.name ?? 'Unknown'}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              // Navigate to Home or Dialpad
              Navigator.of(context).pushReplacementNamed(Routes.home); 
            },
            child: const Text("Go to Home"),
          ),
        ],
      ),
    );
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    _viewModel.updateRegistrationState(state);
  }

  @override
  void callStateChanged(Call call, CallState state) {}

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}
}
