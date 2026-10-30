import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  /// Custom tokens are opaque in this fake: the uid baked into the token string by the tests
  /// below is just echoed back, exactly as the backend-issued one would resolve to a real uid.
  @override
  Future<UserCredential> signInWithCustomToken(String token) async {
    tenantAtCall.add(_tenantId);
    if (failWith != null) throw FirebaseAuthException(code: failWith!);
    return _FakeCredential(_FakeUser(token, null));
  }
}

class _FakeStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];
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

  // POST /api/drivers/session's own backend-mediated fallback (AuthService._signInViaBackendSession)
  // ends by establishing a real, persisted Firebase SDK session from the one-time custom token
  // the backend minted - inside the pool the backend actually verified the password against, not
  // whatever this build's own driverTenantId guess is.
  test('signInWithCustomToken establishes a session inside the backend-resolved tenant', () async {
    final auth = _FakeAuth({});
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    final user = await repo.signInWithCustomToken(
      'custom-token-driver-1',
      tenantId: 'tenant-driver-REAL',
    );

    expect(user.uid, 'custom-token-driver-1');
    expect(user.viaDefaultPool, isFalse);
    expect(auth.tenantAtCall, ['tenant-driver-REAL']);
    expect(
      auth.tenantId,
      'tenant-driver-REAL',
      reason: 'the backend-resolved tenant, not this build\'s own guess',
    );
  });

  test('signInWithCustomToken with no tenantId signs into the shared default pool, flagged as such', () async {
    final auth = _FakeAuth({});
    final repo = AuthRepository(auth: auth, driverTenantId: _tenant);

    final user = await repo.signInWithCustomToken('custom-token-driver-1');

    expect(user.viaDefaultPool, isTrue);
    expect(auth.tenantAtCall, [null]);
    expect(auth.tenantId, isNull);
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

  // auth.tenantId only ever gets set as a side effect of a sign-in call (above) - it is not
  // restored by the SDK itself. A driver signed in via the backend-resolved tenant (not this
  // build's own guess) must not be reported signed-out just because Android killed the app and
  // restarted the process, wiping that in-memory tenantId back to null.
  group('tenant persistence across a fresh process (restorePersistedTenant)', () {
    test('a backend-resolved-tenant session is restored on the next process', () async {
      final auth = _FakeAuth({});
      final storage = _FakeStorage();
      final signedInProcess = AuthRepository(
        auth: auth,
        driverTenantId: _tenant,
        storage: storage,
      );
      await signedInProcess.signInWithCustomToken(
        'custom-token-driver-1',
        tenantId: 'tenant-driver-REAL',
      );
      await pumpEventQueue();

      // A fresh process: a brand-new repository instance, and the fake auth's tenantId reset to
      // null exactly as a freshly-constructed FirebaseAuth would start.
      auth.tenantId = null;
      final freshProcess = AuthRepository(
        auth: auth,
        driverTenantId: _tenant,
        storage: storage,
      );
      await freshProcess.restorePersistedTenant();

      expect(
        auth.tenantId,
        'tenant-driver-REAL',
        reason: 'restored from storage, not this build\'s own driverTenantId guess',
      );
    });

    test('a default-pool session restores to no tenant, not the driver-pool guess', () async {
      final auth = _FakeAuth({
        null: {_email: 'old-pw'},
      });
      final storage = _FakeStorage();
      final signedInProcess = AuthRepository(
        auth: auth,
        driverTenantId: _tenant,
        storage: storage,
      );
      await signedInProcess.signInWithEmail(email: _email, password: 'old-pw');
      await pumpEventQueue();

      auth.tenantId = _tenant;
      final freshProcess = AuthRepository(
        auth: auth,
        driverTenantId: _tenant,
        storage: storage,
      );
      await freshProcess.restorePersistedTenant();

      expect(auth.tenantId, isNull);
    });

    test('signing out clears the persisted tenant so the next process starts clean', () async {
      final auth = _FakeAuth({});
      final storage = _FakeStorage();
      final repo = AuthRepository(
        auth: auth,
        driverTenantId: _tenant,
        storage: storage,
      );
      await repo.signInWithCustomToken(
        'custom-token-driver-1',
        tenantId: 'tenant-driver-REAL',
      );
      await pumpEventQueue();
      expect(storage.values['driver_auth_active_tenant_id'], 'tenant-driver-REAL');

      await repo.signOut();
      await pumpEventQueue();

      expect(storage.values['driver_auth_active_tenant_id'], '');
    });

    test('nothing persisted yet (never signed in on this device) leaves tenantId untouched', () async {
      final auth = _FakeAuth({});
      auth.tenantId = 'whatever-it-already-was';
      final repo = AuthRepository(
        auth: auth,
        driverTenantId: _tenant,
        storage: _FakeStorage(),
      );

      await repo.restorePersistedTenant();

      expect(auth.tenantId, 'whatever-it-already-was');
    });
  });
}
