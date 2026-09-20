import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/data/repositories/auth_repository.dart';

// Driver logins live in their own Firebase Authentication tenant so one email can also be a rider
// account (default pool) with a different password. These tests pin the pool rules with a fake
// FirebaseAuth: new drivers register in the driver pool; sign-in tries the driver pool first and only
// falls back to the default pool for credential problems, flagging that result so the caller can
// confirm it is really a driver account; and with no driver pool configured nothing changes.

const _tenant = 'tenant-driver-1';

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid, this.email);
  @override
  final String uid;
  @override
  final String? email;
  @override
  String? displayName;
  @override
  String? get phoneNumber => null;
  @override
  Future<void> updateDisplayName(String? name) async => displayName = name;
}

class _FakeCredential extends Fake implements UserCredential {
  _FakeCredential(this.user);
  @override
  final User? user;
}

/// accounts: pool key (tenant id, or null for the default pool) -> {email: password}.
class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.accounts, {this.failWith});

  final Map<String?, Map<String, String>> accounts;
  final String? failWith; // error code to throw from every sign-in attempt
  String? _tenantId;
  final List<String?> tenantAtCall = [];

  @override
  String? get tenantId => _tenantId;

  @override
  set tenantId(String? value) => _tenantId = value;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    tenantAtCall.add(_tenantId);
    if (failWith != null) throw FirebaseAuthException(code: failWith!);
    final pool = accounts[_tenantId] ?? {};
    if (!pool.containsKey(email)) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    if (pool[email] != password) {
      throw FirebaseAuthException(code: 'wrong-password');
    }
    return _FakeCredential(_FakeUser('${_tenantId ?? 'default'}:$email', email));
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    tenantAtCall.add(_tenantId);
    final pool = accounts.putIfAbsent(_tenantId, () => {});
    if (pool.containsKey(email)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    pool[email] = password;
    return _FakeCredential(_FakeUser('${_tenantId ?? 'default'}:$email', email));
  }
}

const _email = 'shared@example.com';

void main() {
  test('a driver-pool login signs in through the driver pool, in one attempt', () async {
    final auth = _FakeAuth({
      _tenant: {_email: 'driver-pw'},
    });
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    final user = await repo.signInWithEmail(email: _email, password: 'driver-pw');

    expect(user.viaDefaultPool, isFalse);
    expect(user.uid, '$_tenant:$_email');
    expect(auth.tenantAtCall, [_tenant]);
  });

  test('a driver who registered before driver logins had their own pool still signs in, flagged as default-pool', () async {
    final auth = _FakeAuth({
      null: {_email: 'old-pw'},
    });
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    final user = await repo.signInWithEmail(email: _email, password: 'old-pw');

    expect(user.viaDefaultPool, isTrue);
    expect(user.uid, 'default:$_email');
    expect(auth.tenantAtCall, [_tenant, null], reason: 'driver pool first, then default');
    expect(auth.tenantId, isNull);
  });

  test('one email, two accounts: each password reaches its own account', () async {
    final auth = _FakeAuth({
      null: {_email: 'rider-pw'},
      _tenant: {_email: 'driver-pw'},
    });
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    final driver = await repo.signInWithEmail(email: _email, password: 'driver-pw');
    expect(driver.viaDefaultPool, isFalse);
    expect(driver.uid, startsWith('$_tenant:'));

    // The rider password is found in the default pool and comes back flagged, so the caller's
    // driver-profile check can refuse it - it is NOT silently treated as the driver account.
    final viaRider = await repo.signInWithEmail(email: _email, password: 'rider-pw');
    expect(viaRider.viaDefaultPool, isTrue);
    expect(viaRider.uid, startsWith('default:'));
  });

  test('a wrong password everywhere is reported, not hidden', () async {
    final auth = _FakeAuth({
      _tenant: {_email: 'driver-pw'},
    });
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    await expectLater(
      repo.signInWithEmail(email: _email, password: 'nope'),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(auth.tenantAtCall, [_tenant, null]);
  });

  test('a real problem (too many attempts) is NOT masked by trying the other pool', () async {
    final auth = _FakeAuth({}, failWith: 'too-many-requests');
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    await expectLater(
      repo.signInWithEmail(email: _email, password: 'x'),
      throwsA(
        isA<FirebaseAuthException>().having((e) => e.code, 'code', 'too-many-requests'),
      ),
    );
    expect(auth.tenantAtCall, [_tenant], reason: 'no second attempt for a non-credential error');
  });

  test('sign-up creates the driver account in the driver pool even when the email already has a rider account', () async {
    final auth = _FakeAuth({
      null: {_email: 'rider-pw'},
    });
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    final user = await repo.signUpWithEmail(
      email: _email,
      password: 'driver-pw',
      fullName: 'Test Driver',
    );

    expect(auth.tenantAtCall, [_tenant]);
    expect(user.uid, '$_tenant:$_email');
    expect(user.displayName, 'Test Driver');
    expect(auth.accounts[null], {_email: 'rider-pw'}, reason: 'the rider account is untouched');
    expect(auth.accounts[_tenant], {_email: 'driver-pw'});

    // A second driver sign-up with the same email is a real duplicate.
    await expectLater(
      repo.signUpWithEmail(email: _email, password: 'x', fullName: 'Again'),
      throwsA(
        isA<FirebaseAuthException>().having((e) => e.code, 'code', 'email-already-in-use'),
      ),
    );
  });

  test('with no driver pool configured everything behaves as with one shared pool', () async {
    final auth = _FakeAuth({
      null: {_email: 'pw'},
    });
    final repo = AuthRepository(auth: auth, driverTenantId: '');

    final user = await repo.signInWithEmail(email: _email, password: 'pw');

    expect(user.viaDefaultPool, isFalse);
    expect(auth.tenantAtCall, [null]);
    expect(auth.tenantId, isNull, reason: 'the tenant is never touched');

    await repo.signUpWithEmail(email: 'new@example.com', password: 'pw2', fullName: 'N');
    expect(auth.tenantAtCall, [null, null]);
  });
}
