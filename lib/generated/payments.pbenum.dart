// This is a generated file - do not edit.
//
// Generated from payments.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Status of the request
class Status extends $pb.ProtobufEnum {
  static const Status INFORMATION =
      Status._(0, _omitEnumNames ? '' : 'INFORMATION');
  static const Status SUCCESSFUL =
      Status._(1, _omitEnumNames ? '' : 'SUCCESSFUL');
  static const Status ERROR = Status._(2, _omitEnumNames ? '' : 'ERROR');
  static const Status FAILURE = Status._(3, _omitEnumNames ? '' : 'FAILURE');

  static const $core.List<Status> values = <Status>[
    INFORMATION,
    SUCCESSFUL,
    ERROR,
    FAILURE,
  ];

  static final $core.List<Status?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Status? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Status._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
