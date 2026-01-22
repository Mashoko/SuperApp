// This is a generated file - do not edit.
//
// Generated from users.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'users.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'users.pbenum.dart';

/// Request message on API request
class request extends $pb.GeneratedMessage {
  factory request({
    $core.String? username,
    $core.String? domain,
    $core.String? password,
    $core.double? balance,
    $core.String? email,
    $core.String? packageId,
    $core.String? token,
    $core.String? verificationCode,
    $core.String? debugInfo,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (domain != null) result.domain = domain;
    if (password != null) result.password = password;
    if (balance != null) result.balance = balance;
    if (email != null) result.email = email;
    if (packageId != null) result.packageId = packageId;
    if (token != null) result.token = token;
    if (verificationCode != null) result.verificationCode = verificationCode;
    if (debugInfo != null) result.debugInfo = debugInfo;
    return result;
  }

  request._();

  factory request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'users'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aOS(2, _omitFieldNames ? '' : 'domain')
    ..aOS(3, _omitFieldNames ? '' : 'password')
    ..aD(4, _omitFieldNames ? '' : 'balance')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..aOS(6, _omitFieldNames ? '' : 'packageId')
    ..aOS(7, _omitFieldNames ? '' : 'token')
    ..aOS(8, _omitFieldNames ? '' : 'verificationCode',
        protoName: 'verificationCode')
    ..aOS(9, _omitFieldNames ? '' : 'debugInfo', protoName: 'debugInfo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  request copyWith(void Function(request) updates) =>
      super.copyWith((message) => updates(message as request)) as request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static request create() => request._();
  @$core.override
  request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static request getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<request>(create);
  static request? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get domain => $_getSZ(1);
  @$pb.TagNumber(2)
  set domain($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDomain() => $_has(1);
  @$pb.TagNumber(2)
  void clearDomain() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get password => $_getSZ(2);
  @$pb.TagNumber(3)
  set password($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPassword() => $_has(2);
  @$pb.TagNumber(3)
  void clearPassword() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get balance => $_getN(3);
  @$pb.TagNumber(4)
  set balance($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBalance() => $_has(3);
  @$pb.TagNumber(4)
  void clearBalance() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get packageId => $_getSZ(5);
  @$pb.TagNumber(6)
  set packageId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPackageId() => $_has(5);
  @$pb.TagNumber(6)
  void clearPackageId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get token => $_getSZ(6);
  @$pb.TagNumber(7)
  set token($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasToken() => $_has(6);
  @$pb.TagNumber(7)
  void clearToken() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get verificationCode => $_getSZ(7);
  @$pb.TagNumber(8)
  set verificationCode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVerificationCode() => $_has(7);
  @$pb.TagNumber(8)
  void clearVerificationCode() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get debugInfo => $_getSZ(8);
  @$pb.TagNumber(9)
  set debugInfo($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDebugInfo() => $_has(8);
  @$pb.TagNumber(9)
  void clearDebugInfo() => $_clearField(9);
}

/// Response message on reply to API request
class response extends $pb.GeneratedMessage {
  factory response({
    $core.String? username,
    $core.String? domain,
    $core.String? password,
    $core.double? balance,
    $core.String? email,
    Status? status,
    $core.String? token,
    Error? error,
    Info? info,
    Success? success,
    $core.String? alias,
  }) {
    final result = create();
    if (username != null) result.username = username;
    if (domain != null) result.domain = domain;
    if (password != null) result.password = password;
    if (balance != null) result.balance = balance;
    if (email != null) result.email = email;
    if (status != null) result.status = status;
    if (token != null) result.token = token;
    if (error != null) result.error = error;
    if (info != null) result.info = info;
    if (success != null) result.success = success;
    if (alias != null) result.alias = alias;
    return result;
  }

  response._();

  factory response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'users'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'username')
    ..aOS(2, _omitFieldNames ? '' : 'domain')
    ..aOS(3, _omitFieldNames ? '' : 'password')
    ..aD(4, _omitFieldNames ? '' : 'balance')
    ..aOS(5, _omitFieldNames ? '' : 'email')
    ..aE<Status>(6, _omitFieldNames ? '' : 'status', enumValues: Status.values)
    ..aOS(7, _omitFieldNames ? '' : 'token')
    ..aOM<Error>(8, _omitFieldNames ? '' : 'error', subBuilder: Error.create)
    ..aOM<Info>(9, _omitFieldNames ? '' : 'info', subBuilder: Info.create)
    ..aOM<Success>(10, _omitFieldNames ? '' : 'success',
        subBuilder: Success.create)
    ..aOS(11, _omitFieldNames ? '' : 'alias')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  response copyWith(void Function(response) updates) =>
      super.copyWith((message) => updates(message as response)) as response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static response create() => response._();
  @$core.override
  response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static response getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<response>(create);
  static response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get username => $_getSZ(0);
  @$pb.TagNumber(1)
  set username($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUsername() => $_has(0);
  @$pb.TagNumber(1)
  void clearUsername() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get domain => $_getSZ(1);
  @$pb.TagNumber(2)
  set domain($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDomain() => $_has(1);
  @$pb.TagNumber(2)
  void clearDomain() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get password => $_getSZ(2);
  @$pb.TagNumber(3)
  set password($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPassword() => $_has(2);
  @$pb.TagNumber(3)
  void clearPassword() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get balance => $_getN(3);
  @$pb.TagNumber(4)
  set balance($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBalance() => $_has(3);
  @$pb.TagNumber(4)
  void clearBalance() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get email => $_getSZ(4);
  @$pb.TagNumber(5)
  set email($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEmail() => $_has(4);
  @$pb.TagNumber(5)
  void clearEmail() => $_clearField(5);

  @$pb.TagNumber(6)
  Status get status => $_getN(5);
  @$pb.TagNumber(6)
  set status(Status value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get token => $_getSZ(6);
  @$pb.TagNumber(7)
  set token($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasToken() => $_has(6);
  @$pb.TagNumber(7)
  void clearToken() => $_clearField(7);

  @$pb.TagNumber(8)
  Error get error => $_getN(7);
  @$pb.TagNumber(8)
  set error(Error value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasError() => $_has(7);
  @$pb.TagNumber(8)
  void clearError() => $_clearField(8);
  @$pb.TagNumber(8)
  Error ensureError() => $_ensure(7);

  @$pb.TagNumber(9)
  Info get info => $_getN(8);
  @$pb.TagNumber(9)
  set info(Info value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasInfo() => $_has(8);
  @$pb.TagNumber(9)
  void clearInfo() => $_clearField(9);
  @$pb.TagNumber(9)
  Info ensureInfo() => $_ensure(8);

  @$pb.TagNumber(10)
  Success get success => $_getN(9);
  @$pb.TagNumber(10)
  set success(Success value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSuccess() => $_has(9);
  @$pb.TagNumber(10)
  void clearSuccess() => $_clearField(10);
  @$pb.TagNumber(10)
  Success ensureSuccess() => $_ensure(9);

  @$pb.TagNumber(11)
  $core.String get alias => $_getSZ(10);
  @$pb.TagNumber(11)
  set alias($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAlias() => $_has(10);
  @$pb.TagNumber(11)
  void clearAlias() => $_clearField(11);
}

/// Error message
class Error extends $pb.GeneratedMessage {
  factory Error({
    $core.String? localizedDescription,
    $core.String? debugDescription,
  }) {
    final result = create();
    if (localizedDescription != null)
      result.localizedDescription = localizedDescription;
    if (debugDescription != null) result.debugDescription = debugDescription;
    return result;
  }

  Error._();

  factory Error.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Error.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Error',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'users'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'localizedDescription',
        protoName: 'localizedDescription')
    ..aOS(2, _omitFieldNames ? '' : 'debugDescription',
        protoName: 'debugDescription')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Error copyWith(void Function(Error) updates) =>
      super.copyWith((message) => updates(message as Error)) as Error;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Error create() => Error._();
  @$core.override
  Error createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Error getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Error>(create);
  static Error? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get localizedDescription => $_getSZ(0);
  @$pb.TagNumber(1)
  set localizedDescription($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLocalizedDescription() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocalizedDescription() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get debugDescription => $_getSZ(1);
  @$pb.TagNumber(2)
  set debugDescription($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDebugDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDebugDescription() => $_clearField(2);
}

/// Success message
class Success extends $pb.GeneratedMessage {
  factory Success({
    $core.String? localizedDescription,
    $core.String? debugDescription,
  }) {
    final result = create();
    if (localizedDescription != null)
      result.localizedDescription = localizedDescription;
    if (debugDescription != null) result.debugDescription = debugDescription;
    return result;
  }

  Success._();

  factory Success.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Success.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Success',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'users'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'localizedDescription',
        protoName: 'localizedDescription')
    ..aOS(2, _omitFieldNames ? '' : 'debugDescription',
        protoName: 'debugDescription')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Success clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Success copyWith(void Function(Success) updates) =>
      super.copyWith((message) => updates(message as Success)) as Success;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Success create() => Success._();
  @$core.override
  Success createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Success getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Success>(create);
  static Success? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get localizedDescription => $_getSZ(0);
  @$pb.TagNumber(1)
  set localizedDescription($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLocalizedDescription() => $_has(0);
  @$pb.TagNumber(1)
  void clearLocalizedDescription() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get debugDescription => $_getSZ(1);
  @$pb.TagNumber(2)
  set debugDescription($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDebugDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDebugDescription() => $_clearField(2);
}

/// Info message
class Info extends $pb.GeneratedMessage {
  factory Info({
    $core.String? information,
  }) {
    final result = create();
    if (information != null) result.information = information;
    return result;
  }

  Info._();

  factory Info.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Info.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Info',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'users'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'information')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Info clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Info copyWith(void Function(Info) updates) =>
      super.copyWith((message) => updates(message as Info)) as Info;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Info create() => Info._();
  @$core.override
  Info createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Info getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Info>(create);
  static Info? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get information => $_getSZ(0);
  @$pb.TagNumber(1)
  set information($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasInformation() => $_has(0);
  @$pb.TagNumber(1)
  void clearInformation() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
