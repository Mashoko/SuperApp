// This is a generated file - do not edit.
//
// Generated from payments.proto.

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

import 'payments.pb.dart' as $0;

export 'payments.pb.dart';

/// Service definition for payments
@$pb.GrpcServiceName('payments.paymentsService')
class paymentsServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  paymentsServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.reply> shareAirtime(
    $0.requests request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$shareAirtime, request, options: options);
  }

  $grpc.ResponseFuture<$0.reply> dealerAccountBalances(
    $0.requests request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$dealerAccountBalances, request, options: options);
  }

  $grpc.ResponseFuture<$0.reply> rechargeAccount(
    $0.requests request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$rechargeAccount, request, options: options);
  }

  $grpc.ResponseFuture<$0.reply> reversal(
    $0.requests request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reversal, request, options: options);
  }

  // method descriptors

  static final _$shareAirtime = $grpc.ClientMethod<$0.requests, $0.reply>(
      '/payments.paymentsService/ShareAirtime',
      ($0.requests value) => value.writeToBuffer(),
      $0.reply.fromBuffer);
  static final _$dealerAccountBalances =
      $grpc.ClientMethod<$0.requests, $0.reply>(
          '/payments.paymentsService/DealerAccountBalances',
          ($0.requests value) => value.writeToBuffer(),
          $0.reply.fromBuffer);
  static final _$rechargeAccount = $grpc.ClientMethod<$0.requests, $0.reply>(
      '/payments.paymentsService/RechargeAccount',
      ($0.requests value) => value.writeToBuffer(),
      $0.reply.fromBuffer);
  static final _$reversal = $grpc.ClientMethod<$0.requests, $0.reply>(
      '/payments.paymentsService/Reversal',
      ($0.requests value) => value.writeToBuffer(),
      $0.reply.fromBuffer);
}

@$pb.GrpcServiceName('payments.paymentsService')
abstract class paymentsServiceBase extends $grpc.Service {
  $core.String get $name => 'payments.paymentsService';

  paymentsServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.requests, $0.reply>(
        'ShareAirtime',
        shareAirtime_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.requests.fromBuffer(value),
        ($0.reply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.requests, $0.reply>(
        'DealerAccountBalances',
        dealerAccountBalances_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.requests.fromBuffer(value),
        ($0.reply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.requests, $0.reply>(
        'RechargeAccount',
        rechargeAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.requests.fromBuffer(value),
        ($0.reply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.requests, $0.reply>(
        'Reversal',
        reversal_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.requests.fromBuffer(value),
        ($0.reply value) => value.writeToBuffer()));
  }

  $async.Future<$0.reply> shareAirtime_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.requests> $request) async {
    return shareAirtime($call, await $request);
  }

  $async.Future<$0.reply> shareAirtime(
      $grpc.ServiceCall call, $0.requests request);

  $async.Future<$0.reply> dealerAccountBalances_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.requests> $request) async {
    return dealerAccountBalances($call, await $request);
  }

  $async.Future<$0.reply> dealerAccountBalances(
      $grpc.ServiceCall call, $0.requests request);

  $async.Future<$0.reply> rechargeAccount_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.requests> $request) async {
    return rechargeAccount($call, await $request);
  }

  $async.Future<$0.reply> rechargeAccount(
      $grpc.ServiceCall call, $0.requests request);

  $async.Future<$0.reply> reversal_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.requests> $request) async {
    return reversal($call, await $request);
  }

  $async.Future<$0.reply> reversal($grpc.ServiceCall call, $0.requests request);
}
