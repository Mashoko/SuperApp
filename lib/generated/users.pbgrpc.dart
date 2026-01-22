// This is a generated file - do not edit.
//
// Generated from users.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'users.pb.dart' as $0;

export 'users.pb.dart';

/// Users service definition
@$pb.GrpcServiceName('users.userService')
class userServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  userServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.response> sendVerificationCode(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendVerificationCode, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> sendWhatsAppOTP(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendWhatsAppOTP, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> getDomainForPackageID(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getDomainForPackageID, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> getWebsocketUrl(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getWebsocketUrl, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> getOrignUrl(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getOrignUrl, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> createAccount(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createAccount, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> accountBalance(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$accountBalance, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> deregisterAccount(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deregisterAccount, request, options: options);
  }

  $grpc.ResponseFuture<$0.response> getAliasNumber(
    $0.request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAliasNumber, request, options: options);
  }

  // method descriptors

  static final _$sendVerificationCode =
      $grpc.ClientMethod<$0.request, $0.response>(
          '/users.userService/SendVerificationCode',
          ($0.request value) => value.writeToBuffer(),
          $0.response.fromBuffer);
  static final _$sendWhatsAppOTP = $grpc.ClientMethod<$0.request, $0.response>(
      '/users.userService/SendWhatsAppOTP',
      ($0.request value) => value.writeToBuffer(),
      $0.response.fromBuffer);
  static final _$getDomainForPackageID =
      $grpc.ClientMethod<$0.request, $0.response>(
          '/users.userService/GetDomainForPackageID',
          ($0.request value) => value.writeToBuffer(),
          $0.response.fromBuffer);
  static final _$getWebsocketUrl = $grpc.ClientMethod<$0.request, $0.response>(
      '/users.userService/GetWebsocketUrl',
      ($0.request value) => value.writeToBuffer(),
      $0.response.fromBuffer);
  static final _$getOrignUrl = $grpc.ClientMethod<$0.request, $0.response>(
      '/users.userService/GetOrignUrl',
      ($0.request value) => value.writeToBuffer(),
      $0.response.fromBuffer);
  static final _$createAccount = $grpc.ClientMethod<$0.request, $0.response>(
      '/users.userService/CreateAccount',
      ($0.request value) => value.writeToBuffer(),
      $0.response.fromBuffer);
  static final _$accountBalance = $grpc.ClientMethod<$0.request, $0.response>(
      '/users.userService/AccountBalance',
      ($0.request value) => value.writeToBuffer(),
      $0.response.fromBuffer);
  static final _$deregisterAccount =
      $grpc.ClientMethod<$0.request, $0.response>(
          '/users.userService/DeregisterAccount',
          ($0.request value) => value.writeToBuffer(),
          $0.response.fromBuffer);
  static final _$getAliasNumber = $grpc.ClientMethod<$0.request, $0.response>(
      '/users.userService/GetAliasNumber',
      ($0.request value) => value.writeToBuffer(),
      $0.response.fromBuffer);
}

@$pb.GrpcServiceName('users.userService')
abstract class userServiceBase extends $grpc.Service {
  $core.String get $name => 'users.userService';

  userServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'SendVerificationCode',
        sendVerificationCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'SendWhatsAppOTP',
        sendWhatsAppOTP_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'GetDomainForPackageID',
        getDomainForPackageID_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'GetWebsocketUrl',
        getWebsocketUrl_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'GetOrignUrl',
        getOrignUrl_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'CreateAccount',
        createAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'AccountBalance',
        accountBalance_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'DeregisterAccount',
        deregisterAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.request, $0.response>(
        'GetAliasNumber',
        getAliasNumber_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.request.fromBuffer(value),
        ($0.response value) => value.writeToBuffer()));
  }

  $async.Future<$0.response> sendVerificationCode_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return sendVerificationCode($call, await $request);
  }

  $async.Future<$0.response> sendVerificationCode(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> sendWhatsAppOTP_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return sendWhatsAppOTP($call, await $request);
  }

  $async.Future<$0.response> sendWhatsAppOTP(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> getDomainForPackageID_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return getDomainForPackageID($call, await $request);
  }

  $async.Future<$0.response> getDomainForPackageID(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> getWebsocketUrl_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return getWebsocketUrl($call, await $request);
  }

  $async.Future<$0.response> getWebsocketUrl(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> getOrignUrl_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return getOrignUrl($call, await $request);
  }

  $async.Future<$0.response> getOrignUrl(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> createAccount_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return createAccount($call, await $request);
  }

  $async.Future<$0.response> createAccount(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> accountBalance_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return accountBalance($call, await $request);
  }

  $async.Future<$0.response> accountBalance(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> deregisterAccount_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return deregisterAccount($call, await $request);
  }

  $async.Future<$0.response> deregisterAccount(
      $grpc.ServiceCall call, $0.request request);

  $async.Future<$0.response> getAliasNumber_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.request> $request) async {
    return getAliasNumber($call, await $request);
  }

  $async.Future<$0.response> getAliasNumber(
      $grpc.ServiceCall call, $0.request request);
}
