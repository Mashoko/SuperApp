import 'package:flutter_test/flutter_test.dart';
import 'package:mvvm_sip_demo/core/utils/result.dart';
import 'package:mvvm_sip_demo/features/call/domain/repositories/call_repository.dart';
import 'package:mvvm_sip_demo/features/call/domain/usecases/make_call.dart';

class _FakeRepo implements CallRepository {
  final List<String> dialled = [];

  @override
  Future<Result<void>> makeCall(String destination,
      {required bool voiceOnly}) async {
    dialled.add(destination);
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _msg =
    'Calls are paused until you complete your KYC verification. Emergency calls still work.';

void main() {
  test('restricted blocks a normal number without calling the repository',
      () async {
    final repo = _FakeRepo();
    final r = await MakeCall(repo, isKycRestricted: () => true)
        .call('0770000000', voiceOnly: true);
    expect(r, isA<Failure<void>>());
    expect((r as Failure<void>).message, _msg);
    expect(repo.dialled, isEmpty);
  });

  test('restricted still allows emergency numbers', () async {
    final repo = _FakeRepo();
    final r = await MakeCall(repo, isKycRestricted: () => true)
        .call('999', voiceOnly: true);
    expect(r, isA<Success<void>>());
    expect(repo.dialled, ['999']);
  });

  test('not restricted calls through', () async {
    final repo = _FakeRepo();
    final r = await MakeCall(repo, isKycRestricted: () => false)
        .call('0770000000', voiceOnly: true);
    expect(r, isA<Success<void>>());
    expect(repo.dialled, ['0770000000']);
  });

  test('no closure means not restricted', () async {
    final repo = _FakeRepo();
    await MakeCall(repo).call('0770000000', voiceOnly: true);
    expect(repo.dialled, ['0770000000']);
  });
}
