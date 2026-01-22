import 'package:flutter/material.dart';

import '../models/operation_state.dart';
import '../users_client.dart';
import '../generated/users.pb.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required UsersClient usersClient}) : _client = usersClient;

  final UsersClient _client;

  OperationState smsOtpState = OperationState.idle;
  OperationState whatsappOtpState = OperationState.idle;
  OperationState domainState = OperationState.idle;
  OperationState aliasState = OperationState.idle;

  String? allowedDomain;
  String? aliasNumber;

  Future<void> sendSmsOtp({
    required String username,
    required String phone,
  }) async {
    smsOtpState = OperationState.loading('Sending SMS...');
    notifyListeners();

    final resp = await _client.sendVerificationCode(
      username: username,
      phone: phone,
    );
    smsOtpState = _mapResponse(resp, successMessage: 'OTP sent via SMS');
    notifyListeners();
  }

  Future<void> sendWhatsappOtp({
    required String username,
    required String phone,
  }) async {
    whatsappOtpState = OperationState.loading('Sending WhatsApp OTP...');
    notifyListeners();

    final resp = await _client.sendWhatsAppOTP(
      username: username,
      phone: phone,
    );
    whatsappOtpState =
        _mapResponse(resp, successMessage: 'OTP sent via WhatsApp');
    notifyListeners();
  }

  Future<void> fetchAllowedDomain() async {
    domainState = OperationState.loading('Requesting...');
    notifyListeners();

    final resp = await _client.getDomainForPackageID();
    if (_didSucceed(resp)) {
      allowedDomain = resp.domain;
      final domainLabel =
          resp.domain.isNotEmpty ? resp.domain : 'not provided by API';
      domainState = OperationState.success('Allowed domain: $domainLabel');
    } else {
      domainState = OperationState.error(_errorMessage(resp));
    }
    notifyListeners();
  }

  Future<void> fetchAliasNumber({required String username}) async {
    aliasState = OperationState.loading('Fetching alias...');
    notifyListeners();

    final resp = await _client.getAliasNumber(username: username);
    if (_didSucceed(resp)) {
      aliasNumber = resp.alias;
      aliasState = OperationState.success('Alias updated');
    } else {
      aliasState = OperationState.error(_errorMessage(resp));
    }
    notifyListeners();
  }

  OperationState _mapResponse(
    response resp, {
    required String successMessage,
  }) {
    if (_didSucceed(resp)) {
      return OperationState.success(successMessage);
    }
    return OperationState.error(_errorMessage(resp));
  }

  bool _didSucceed(response resp) {
    return resp.status == Status.SUCCESS || resp.status == Status.INFORMATION;
  }

  String _errorMessage(response resp) {
    if (resp.hasError()) {
      final err = resp.error;
      return err.localizedDescription.isNotEmpty
          ? err.localizedDescription
          : err.debugDescription;
    }
    return 'Unexpected response';
  }
}

