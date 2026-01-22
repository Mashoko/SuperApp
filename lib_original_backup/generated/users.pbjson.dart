// This is a generated file - do not edit.
//
// Generated from users.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use statusDescriptor instead')
const Status$json = {
  '1': 'Status',
  '2': [
    {'1': 'INFORMATION', '2': 0},
    {'1': 'SUCCESS', '2': 1},
    {'1': 'ERROR', '2': 2},
    {'1': 'FAILED', '2': 3},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSDwoLSU5GT1JNQVRJT04QABILCgdTVUNDRVNTEAESCQoFRVJST1IQAhIKCgZGQU'
    'lMRUQQAw==');

@$core.Deprecated('Use requestDescriptor instead')
const request$json = {
  '1': 'request',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'domain', '3': 2, '4': 1, '5': 9, '10': 'domain'},
    {'1': 'password', '3': 3, '4': 1, '5': 9, '10': 'password'},
    {'1': 'balance', '3': 4, '4': 1, '5': 1, '10': 'balance'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '10': 'email'},
    {'1': 'package_id', '3': 6, '4': 1, '5': 9, '10': 'packageId'},
    {'1': 'token', '3': 7, '4': 1, '5': 9, '10': 'token'},
    {'1': 'verificationCode', '3': 8, '4': 1, '5': 9, '10': 'verificationCode'},
    {'1': 'debugInfo', '3': 9, '4': 1, '5': 9, '10': 'debugInfo'},
  ],
};

/// Descriptor for `request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestDescriptor = $convert.base64Decode(
    'CgdyZXF1ZXN0EhoKCHVzZXJuYW1lGAEgASgJUgh1c2VybmFtZRIWCgZkb21haW4YAiABKAlSBm'
    'RvbWFpbhIaCghwYXNzd29yZBgDIAEoCVIIcGFzc3dvcmQSGAoHYmFsYW5jZRgEIAEoAVIHYmFs'
    'YW5jZRIUCgVlbWFpbBgFIAEoCVIFZW1haWwSHQoKcGFja2FnZV9pZBgGIAEoCVIJcGFja2FnZU'
    'lkEhQKBXRva2VuGAcgASgJUgV0b2tlbhIqChB2ZXJpZmljYXRpb25Db2RlGAggASgJUhB2ZXJp'
    'ZmljYXRpb25Db2RlEhwKCWRlYnVnSW5mbxgJIAEoCVIJZGVidWdJbmZv');

@$core.Deprecated('Use responseDescriptor instead')
const response$json = {
  '1': 'response',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'domain', '3': 2, '4': 1, '5': 9, '10': 'domain'},
    {'1': 'password', '3': 3, '4': 1, '5': 9, '10': 'password'},
    {'1': 'balance', '3': 4, '4': 1, '5': 1, '10': 'balance'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '10': 'email'},
    {
      '1': 'status',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.users.Status',
      '10': 'status'
    },
    {'1': 'token', '3': 7, '4': 1, '5': 9, '10': 'token'},
    {'1': 'error', '3': 8, '4': 1, '5': 11, '6': '.users.Error', '10': 'error'},
    {'1': 'info', '3': 9, '4': 1, '5': 11, '6': '.users.Info', '10': 'info'},
    {
      '1': 'success',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.users.Success',
      '10': 'success'
    },
    {'1': 'alias', '3': 11, '4': 1, '5': 9, '10': 'alias'},
  ],
};

/// Descriptor for `response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List responseDescriptor = $convert.base64Decode(
    'CghyZXNwb25zZRIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWUSFgoGZG9tYWluGAIgASgJUg'
    'Zkb21haW4SGgoIcGFzc3dvcmQYAyABKAlSCHBhc3N3b3JkEhgKB2JhbGFuY2UYBCABKAFSB2Jh'
    'bGFuY2USFAoFZW1haWwYBSABKAlSBWVtYWlsEiUKBnN0YXR1cxgGIAEoDjINLnVzZXJzLlN0YX'
    'R1c1IGc3RhdHVzEhQKBXRva2VuGAcgASgJUgV0b2tlbhIiCgVlcnJvchgIIAEoCzIMLnVzZXJz'
    'LkVycm9yUgVlcnJvchIfCgRpbmZvGAkgASgLMgsudXNlcnMuSW5mb1IEaW5mbxIoCgdzdWNjZX'
    'NzGAogASgLMg4udXNlcnMuU3VjY2Vzc1IHc3VjY2VzcxIUCgVhbGlhcxgLIAEoCVIFYWxpYXM=');

@$core.Deprecated('Use errorDescriptor instead')
const Error$json = {
  '1': 'Error',
  '2': [
    {
      '1': 'localizedDescription',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'localizedDescription'
    },
    {'1': 'debugDescription', '3': 2, '4': 1, '5': 9, '10': 'debugDescription'},
  ],
};

/// Descriptor for `Error`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDescriptor = $convert.base64Decode(
    'CgVFcnJvchIyChRsb2NhbGl6ZWREZXNjcmlwdGlvbhgBIAEoCVIUbG9jYWxpemVkRGVzY3JpcH'
    'Rpb24SKgoQZGVidWdEZXNjcmlwdGlvbhgCIAEoCVIQZGVidWdEZXNjcmlwdGlvbg==');

@$core.Deprecated('Use successDescriptor instead')
const Success$json = {
  '1': 'Success',
  '2': [
    {
      '1': 'localizedDescription',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'localizedDescription'
    },
    {'1': 'debugDescription', '3': 2, '4': 1, '5': 9, '10': 'debugDescription'},
  ],
};

/// Descriptor for `Success`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List successDescriptor = $convert.base64Decode(
    'CgdTdWNjZXNzEjIKFGxvY2FsaXplZERlc2NyaXB0aW9uGAEgASgJUhRsb2NhbGl6ZWREZXNjcm'
    'lwdGlvbhIqChBkZWJ1Z0Rlc2NyaXB0aW9uGAIgASgJUhBkZWJ1Z0Rlc2NyaXB0aW9u');

@$core.Deprecated('Use infoDescriptor instead')
const Info$json = {
  '1': 'Info',
  '2': [
    {'1': 'information', '3': 1, '4': 1, '5': 9, '10': 'information'},
  ],
};

/// Descriptor for `Info`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List infoDescriptor = $convert
    .base64Decode('CgRJbmZvEiAKC2luZm9ybWF0aW9uGAEgASgJUgtpbmZvcm1hdGlvbg==');
