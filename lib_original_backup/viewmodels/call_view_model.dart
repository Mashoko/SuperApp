import 'package:flutter/material.dart';

import '../generated/users.pb.dart';
import '../models/account_summary.dart';
import '../models/operation_state.dart';
import '../models/sip_config.dart';
import '../users_client.dart';

class CallViewModel extends ChangeNotifier {
  CallViewModel({required UsersClient usersClient}) : _client = usersClient;

  final UsersClient _client;

  OperationState sipState = OperationState.idle;
  OperationState accountState = OperationState.idle;

  SipConfig? sipConfig;
  AccountSummary? accountSummary;
  String _dialedNumber = '';

  String? _lastUsername;
  String? _lastPassword;

  String get dialedNumber => _dialedNumber;
  String? get lastUsername => _lastUsername;
  String? get lastPassword => _lastPassword;

  void appendDialInput(String value) {
    if (_dialedNumber.length > 24) return;
    _dialedNumber += value;
    notifyListeners();
  }

  void removeLastDialInput() {
    if (_dialedNumber.isEmpty) return;
    _dialedNumber = _dialedNumber.substring(0, _dialedNumber.length - 1);
    notifyListeners();
  }

  void clearDialInput() {
    if (_dialedNumber.isEmpty) return;
    _dialedNumber = '';
    notifyListeners();
  }

  void placeCall() {
    // Placeholder for future SIP call initiation.
  }

  Future<void> loadSipConfig() async {
    sipState = OperationState.loading('Contacting SIP backend...');
    notifyListeners();

    final wsResp = await _client.getWebsocketUrlFromApi();
    if (!_didSucceed(wsResp)) {
      sipState = OperationState.error(_errorMessage(wsResp));
      notifyListeners();
      return;
    }

    final originResp = await _client.getOriginUrlFromApi();
    if (!_didSucceed(originResp)) {
      sipState = OperationState.error(_errorMessage(originResp));
      notifyListeners();
      return;
    }

    final websocket =
        wsResp.domain.isNotEmpty ? wsResp.domain : _client.websocketUrl;
    final origin = originResp.domain.isNotEmpty
        ? originResp.domain
        : _client.originUrl;

    sipConfig = SipConfig(
      websocketUrl: websocket,
      origin: origin,
      transport: UsersClient.sipTransport,
      port: UsersClient.sipPort,
    );
    sipState = OperationState.success('SIP config ready');
    notifyListeners();
  }

  Future<void> refreshAccount({
    required String username,
    String? password,
  }) async {
    accountState = OperationState.loading('Fetching account...');
    notifyListeners();

    final resp = await _client.getAccountBalance(
      username: username,
      password: password,
    );

    if (!_didSucceed(resp)) {
      accountState = OperationState.error(_errorMessage(resp));
      notifyListeners();
      return;
    }

    var alias = resp.alias;
    if (alias.isEmpty) {
      final aliasResp = await _client.getAliasNumber(username: username);
      if (_didSucceed(aliasResp)) {
        alias = aliasResp.alias;
      }
    }

    accountSummary = AccountSummary(
      username: username,
      alias: alias,
      balance: resp.balance,
      domain: resp.domain,
      status: resp.status.name,
      infoMessage: resp.hasInfo() ? resp.info.information : null,
    );
    accountState = OperationState.success('Account refreshed');
    _lastUsername = username;
    _lastPassword = password;
    notifyListeners();
  }

  Future<bool> refreshCachedAccount() async {
    if (_lastUsername == null) return false;
    await refreshAccount(
      username: _lastUsername!,
      password: _lastPassword,
    );
    return true;
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

