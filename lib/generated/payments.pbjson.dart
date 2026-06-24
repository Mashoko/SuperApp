// This is a generated file - do not edit.
//
// Generated from payments.proto.

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
    {'1': 'SUCCESSFUL', '2': 1},
    {'1': 'ERROR', '2': 2},
    {'1': 'FAILURE', '2': 3},
  ],
};

/// Descriptor for `Status`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List statusDescriptor = $convert.base64Decode(
    'CgZTdGF0dXMSDwoLSU5GT1JNQVRJT04QABIOCgpTVUNDRVNTRlVMEAESCQoFRVJST1IQAhILCg'
    'dGQUlMVVJFEAM=');

@$core.Deprecated('Use requestsDescriptor instead')
const requests$json = {
  '1': 'requests',
  '2': [
    {'1': 'username', '3': 1, '4': 1, '5': 9, '10': 'username'},
    {'1': 'domain', '3': 2, '4': 1, '5': 9, '10': 'domain'},
    {'1': 'password', '3': 3, '4': 1, '5': 9, '10': 'password'},
    {'1': 'balance', '3': 4, '4': 1, '5': 1, '10': 'balance'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '10': 'email'},
    {'1': 'package_id', '3': 6, '4': 1, '5': 9, '10': 'packageId'},
    {'1': 'token', '3': 7, '4': 1, '5': 9, '10': 'token'},
    {'1': 'receiver', '3': 8, '4': 1, '5': 9, '10': 'receiver'},
    {'1': 'amount', '3': 9, '4': 1, '5': 1, '10': 'amount'},
    {'1': 'voucherPin', '3': 10, '4': 1, '5': 9, '10': 'voucherPin'},
    {'1': 'debugInfo', '3': 11, '4': 1, '5': 9, '10': 'debugInfo'},
    {'1': 'transactionId', '3': 12, '4': 1, '5': 9, '10': 'transactionId'},
  ],
};

/// Descriptor for `requests`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestsDescriptor = $convert.base64Decode(
    'CghyZXF1ZXN0cxIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWUSFgoGZG9tYWluGAIgASgJUg'
    'Zkb21haW4SGgoIcGFzc3dvcmQYAyABKAlSCHBhc3N3b3JkEhgKB2JhbGFuY2UYBCABKAFSB2Jh'
    'bGFuY2USFAoFZW1haWwYBSABKAlSBWVtYWlsEh0KCnBhY2thZ2VfaWQYBiABKAlSCXBhY2thZ2'
    'VJZBIUCgV0b2tlbhgHIAEoCVIFdG9rZW4SGgoIcmVjZWl2ZXIYCCABKAlSCHJlY2VpdmVyEhYK'
    'BmFtb3VudBgJIAEoAVIGYW1vdW50Eh4KCnZvdWNoZXJQaW4YCiABKAlSCnZvdWNoZXJQaW4SHA'
    'oJZGVidWdJbmZvGAsgASgJUglkZWJ1Z0luZm8SJAoNdHJhbnNhY3Rpb25JZBgMIAEoCVINdHJh'
    'bnNhY3Rpb25JZA==');

@$core.Deprecated('Use replyDescriptor instead')
const reply$json = {
  '1': 'reply',
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
      '6': '.payments.Status',
      '10': 'status'
    },
    {'1': 'token', '3': 7, '4': 1, '5': 9, '10': 'token'},
    {
      '1': 'error',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.payments.Error',
      '10': 'error'
    },
    {'1': 'info', '3': 9, '4': 1, '5': 11, '6': '.payments.Info', '10': 'info'},
    {
      '1': 'success',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.payments.Success',
      '10': 'success'
    },
    {'1': 'balanceAfter', '3': 11, '4': 1, '5': 1, '10': 'balanceAfter'},
  ],
};

/// Descriptor for `reply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replyDescriptor = $convert.base64Decode(
    'CgVyZXBseRIaCgh1c2VybmFtZRgBIAEoCVIIdXNlcm5hbWUSFgoGZG9tYWluGAIgASgJUgZkb2'
    '1haW4SGgoIcGFzc3dvcmQYAyABKAlSCHBhc3N3b3JkEhgKB2JhbGFuY2UYBCABKAFSB2JhbGFu'
    'Y2USFAoFZW1haWwYBSABKAlSBWVtYWlsEigKBnN0YXR1cxgGIAEoDjIQLnBheW1lbnRzLlN0YX'
    'R1c1IGc3RhdHVzEhQKBXRva2VuGAcgASgJUgV0b2tlbhIlCgVlcnJvchgIIAEoCzIPLnBheW1l'
    'bnRzLkVycm9yUgVlcnJvchIiCgRpbmZvGAkgASgLMg4ucGF5bWVudHMuSW5mb1IEaW5mbxIrCg'
    'dzdWNjZXNzGAogASgLMhEucGF5bWVudHMuU3VjY2Vzc1IHc3VjY2VzcxIiCgxiYWxhbmNlQWZ0'
    'ZXIYCyABKAFSDGJhbGFuY2VBZnRlcg==');

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
