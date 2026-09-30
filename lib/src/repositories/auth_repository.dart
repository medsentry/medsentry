import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../config/seed_credentials.dart';
import '../database/simple_database.dart';
import '../models/audit_log.dart';
import '../models/user.dart';
import '../services/audit_service.dart';
import '../utils/password_crypto.dart';

class AuthRepository {
  static const String _legacyStaffEmail = 'staff@rhu.gov.ph';
  static const bool _allowDefaultAdmin = bool.fromEnvironment(
    'MEDSENTRY_ALLOW_DEFAULT_ADMIN',
    defaultValue: false,
  );
  static const String _currentUserIdKey = 'medsentry.current_user_id';
  static const String _lastUserIdKey = 'medsentry.last_user_id';
  static const String _sessionLockedKey = 'medsentry.session_locked';

  final SimpleDatabase _db;
  final AuditService _auditService;
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Store last logged in user ID for PIN login
  String? _lastLoggedInUserId;
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  AuthRepository(this._db, this._auditService);

  String _hashPassword(String password) => PasswordCrypto.hash(password);

  bool _verifyPassword(String password, String storedHash) =>
      PasswordCrypto.verify(password, storedHash);

  Future<void> _setCurrentUserId(String userId) async {
    _lastLoggedInUserId = userId;
    try {
      await _secureStorage.write(key: _currentUserIdKey, value: userId);
      await _secureStorage.write(key: _lastUserIdKey, value: userId);
    } catch (_) {
      // Secure storage may not be available on all desktop setups; persist to disk as fallback
      await _db.setLastUserId(userId);
    }
    // Always keep a disk-backed fallback
    await _db.setLastUserId(userId);
  }

  Future<String?> _getLastLoggedInUserId() async {
    if (_lastLoggedInUserId != null) return _lastLoggedInUserId;
    try {
      final v = await _secureStorage.read(key: _lastUserIdKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {
      // ignore secure storage errors
    }
    // Fallback to disk-backed value
    return await _db.getLastUserId();
  }

  Future<bool> isSessionLocked() async {
    try {
      return await _secureStorage.read(key: _sessionLockedKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> _setSessionLocked(bool locked) async {
    try {
      if (locked) {
        await _secureStorage.write(key: _sessionLockedKey, value: 'true');
      } else {
        await _secureStorage.delete(key: _sessionLockedKey);
      }
    } catch (_) {
      // Secure storage may be unavailable on some desktop setups.
    }
  }

  Future<void> unlockSession() async {
    await _setSessionLocked(false);
  }

  /// Ensures built-in dev accounts exist for every role with secured hashes.
  Future<void> ensureDefaultAccounts({bool force = false}) async {
    if (!_allowDefaultAdmin && !force) return;
    if (SeedCredentials.defaultPassword.length < 12) {
      throw StateError(
        'MEDSENTRY_SEED_PASSWORD must be set to a strong development-only password',
      );
    }
    await _migrateLegacyStaffEmail();
    for (final account in SeedCredentials.accounts) {
      await _ensureSeedAccount(account);
    }
  }

  String? _cachedSeedPasswordHash;

  String _getSeedPasswordHash() => _cachedSeedPasswordHash ??= _hashPassword(
    SeedCredentials.defaultPassword,
  );

  Future<void> _migrateLegacyStaffEmail() async {
    final legacyUser = await _db.getUserByEmail(_legacyStaffEmail);
    if (legacyUser == null) return;
    final staffAccount = SeedCredentials.accounts.firstWhere(
      (a) => a.email == 'staff@gmail.com',
    );
    final existingStaff = await _db.getUserByEmail(staffAccount.email);
    if (existingStaff != null) return;

    await _db.updateUser(
      legacyUser.copyWith(email: staffAccount.email, updatedAt: DateTime.now()),
    );
  }

  Future<User> _ensureSeedAccount(SeedAccount account) async {
    final existingUser = await _db.getUserByEmail(account.email);
    if (existingUser != null) {
      return existingUser;
    }

    final now = DateTime.now();
    final passwordHash = _getSeedPasswordHash();

    final user = User(
      id: account.id,
      email: account.email,
      firstName: account.firstName,
      lastName: account.lastName,
      role: account.role,
      licenseNumber: account.licenseNumber,
      specialization: account.specialization,
      contactNumber: account.contactNumber,
      isActive: true,
      pinEnabled: false,
      pinHash: null,
      createdAt: now,
      updatedAt: now,
      syncStatus: 0,
    );

    await _db.insertUser(user, passwordHash: passwordHash);
    return user;
  }

  SeedAccount? _seedAccountForEmail(String email) {
    for (final account in SeedCredentials.accounts) {
      if (account.email == email) return account;
    }
    return null;
  }

  // Create new user
  Future<User> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? licenseNumber,
    String? specialization,
    String? contactNumber,
    bool pinEnabled = false,
    String? pin,
    required String createdByUserId,
  }) async {
    await _requireSystemManager(createdByUserId);
    _validateEmail(email);
    _validateRequiredName(firstName, 'First name');
    _validateRequiredName(lastName, 'Last name');
    await _validatePassword(password);
    if (_supabase.auth.currentSession == null) {
      throw StateError(
        'Staff accounts must be provisioned online as an administrator',
      );
    }
    if (pinEnabled && (pin == null || !RegExp(r'^\d{4}$').hasMatch(pin))) {
      throw ArgumentError('Enabled PIN must be exactly 4 digits');
    }
    final pinHash = pinEnabled ? _hashPassword(pin!) : null;

    // Check if email already exists
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();
    final existingUser = await _db.getUserByEmail(normalizedEmail);
    if (existingUser != null) {
      throw ArgumentError('Email already exists');
    }

    final response = await _supabase.functions.invoke(
      'provision-user',
      body: {
        'action': 'create',
        'email': normalizedEmail,
        'password': password,
        'first_name': normalizedFirstName,
        'last_name': normalizedLastName,
        'role': role.name,
        'license_number': licenseNumber,
        'specialization': specialization,
        'contact_number': contactNumber,
      },
    );
    final profile = Map<String, dynamic>.from(response.data as Map);
    final id = profile['id'] as String;
    final now = DateTime.now();

    final user = User(
      id: id,
      email: normalizedEmail,
      firstName: normalizedFirstName,
      lastName: normalizedLastName,
      role: role,
      licenseNumber: licenseNumber,
      specialization: specialization,
      contactNumber: contactNumber,
      isActive: true,
      pinEnabled: pinEnabled,
      pinHash: pinHash,
      createdAt: now,
      updatedAt: now,
      syncStatus: 0,
    );

    await _db.insertUser(user);

    await _auditService.logAction(
      userId: createdByUserId,
      action: AuditAction.create,
      entityType: 'user',
      entityId: id,
      description: 'Created user: $normalizedEmail with role ${role.name}',
    );

    return user;
  }

  // Authenticate user with email and password using Supabase or a local account.
  Future<User?> authenticate(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (_allowDefaultAdmin) {
      final seedAccount = _seedAccountForEmail(normalizedEmail);
      if (seedAccount != null && password == SeedCredentials.defaultPassword) {
        final user = await _ensureSeedAccount(seedAccount);
        await _db.updateUserLastLogin(user.id);
        await _setCurrentUserId(user.id);
        await unlockSession();
        return user;
      }
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );

      if (response.user == null) {
        return null;
      }

      final cachedUser = await _db.getUserByEmail(normalizedEmail);
      final profile = await _supabase
          .from('users')
          .select(
            'id,email,first_name,last_name,role,license_number,specialization,'
            'contact_number,profile_image_url,is_active,pin_enabled,'
            'last_login_at,created_at,updated_at',
          )
          .eq('auth_user_id', response.user!.id)
          .maybeSingle();

      if (profile == null) {
        await _supabase.auth.signOut();
        return null;
      }

      final serverUser = User.fromJson(Map<String, dynamic>.from(profile));
      final localUser = serverUser.copyWith(pinHash: cachedUser?.pinHash);
      if (!localUser.isActive) {
        await _supabase.auth.signOut();
        return null;
      }

      try {
        await _supabase.rpc(
          'medsentry_log_auth_event',
          params: {'event_action': 'LOGIN'},
        );
      } catch (_) {
        await _supabase.auth.signOut();
        return null;
      }

      if (cachedUser == null) {
        await _db.insertUser(localUser);
      } else {
        await _db.updateUser(localUser);
      }
      await _db.clearUserPasswordHash(localUser.id);

      await _db.updateUserLastLogin(localUser.id);

      await _auditService.logAction(
        userId: localUser.id,
        action: AuditAction.login,
        entityType: 'user',
        entityId: localUser.id,
        description: 'User logged in via Supabase: $normalizedEmail',
      );

      // Store the user ID for PIN login
      await _setCurrentUserId(localUser.id);
      await unlockSession();
      return localUser;
    } on AuthException {
      return await _isDeviceOffline()
          ? _authenticateLocal(normalizedEmail, password)
          : null;
    } catch (_) {
      return await _isDeviceOffline()
          ? _authenticateLocal(normalizedEmail, password)
          : null;
    }
  }

  Future<bool> _isDeviceOffline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.every((result) => result == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Future<User?> _authenticateLocal(
    String normalizedEmail,
    String password,
  ) async {
    if (!_allowDefaultAdmin || _seedAccountForEmail(normalizedEmail) == null) {
      return null;
    }
    final localUser = await _db.getUserByEmail(normalizedEmail);
    if (localUser == null || !localUser.isActive) return null;

    final storedHash = await _db.getUserPasswordHash(localUser.id);
    if (storedHash == null || !_verifyPassword(password, storedHash)) {
      await _auditService.logAction(
        userId: localUser.id,
        action: AuditAction.login,
        entityType: 'user',
        entityId: localUser.id,
        description: 'Failed local login attempt for $normalizedEmail',
      );
      return null;
    }

    if (!storedHash.startsWith('pbkdf2_sha256:')) {
      await _db.updateUserPassword(localUser.id, _hashPassword(password));
    }

    await _db.updateUserLastLogin(localUser.id);
    await _setCurrentUserId(localUser.id);
    await unlockSession();
    await _auditService.logAction(
      userId: localUser.id,
      action: AuditAction.login,
      entityType: 'user',
      entityId: localUser.id,
      description: 'User logged in locally: $normalizedEmail',
    );
    return localUser;
  }

  // Verify PIN for quick unlock
  Future<bool> verifyPin(String userId, String pin) async {
    final user = await _db.getUserById(userId);
    if (user == null) return false;

    if (!user.pinEnabled || user.pinHash == null) {
      return false;
    }

    return _verifyPassword(pin, user.pinHash!);
  }

  // Get user by ID
  Future<User?> getUserById(String id) async {
    return await _db.getUserById(id);
  }

  // Get all users
  Future<List<User>> getAllUsers() async {
    return await _db.getAllUsers();
  }

  // Update user
  Future<User> updateUser({
    required String id,
    String? firstName,
    String? lastName,
    String? contactNumber,
    String? specialization,
    UserRole? role,
    bool? isActive,
    bool? pinEnabled,
    String? newPassword,
    String? newPin,
    required String updatedByUserId,
  }) async {
    final existing = await _db.getUserById(id);
    if (existing == null) {
      throw ArgumentError('User not found');
    }
    final actor = await _db.getUserById(updatedByUserId);
    if (actor == null || !actor.isActive) {
      throw StateError('An active user session is required');
    }
    final changesAccess =
        (role != null && role != existing.role) ||
        (isActive != null && isActive != existing.isActive) ||
        newPassword != null ||
        newPin != null ||
        pinEnabled != null;
    if (actor.id != id && !actor.canManageSystemData) {
      throw StateError('You are not allowed to update this account');
    }
    if (actor.id == id && changesAccess && !actor.canManageSystemData) {
      throw StateError('Only an administrator can change account access');
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      await _validatePassword(newPassword);
      if (_supabase.auth.currentSession == null) {
        throw StateError(
          'Password changes require an online administrator session',
        );
      }
      await _supabase.functions.invoke(
        'provision-user',
        body: {
          'action': 'set_password',
          'target_user_id': id,
          'password': newPassword,
        },
      );
      await _db.clearUserPasswordHash(id);
    }

    // Hash new PIN if provided
    String? newPinHash;
    if (newPin != null && newPin.isNotEmpty) {
      if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
        throw ArgumentError('PIN must be 4 digits');
      }
      newPinHash = _hashPassword(newPin);
    }

    final updated = existing.copyWith(
      firstName: firstName ?? existing.firstName,
      lastName: lastName ?? existing.lastName,
      contactNumber: contactNumber ?? existing.contactNumber,
      specialization: specialization ?? existing.specialization,
      role: role ?? existing.role,
      isActive: isActive ?? existing.isActive,
      pinEnabled: pinEnabled ?? existing.pinEnabled,
      updatedAt: DateTime.now(),
      syncStatus: existing.syncStatus == 0 ? 2 : existing.syncStatus,
    );

    final accountChanged =
        updated.firstName != existing.firstName ||
        updated.lastName != existing.lastName ||
        updated.contactNumber != existing.contactNumber ||
        updated.specialization != existing.specialization ||
        updated.role != existing.role ||
        updated.isActive != existing.isActive;
    if (accountChanged && _supabase.auth.currentSession == null) {
      throw StateError('Account changes require an online Supabase session');
    }
    if (accountChanged) {
      await _supabase.rpc(
        'medsentry_update_user_account',
        params: {
          'target_user_id': id,
          'requested_role': updated.role.name,
          'requested_active': updated.isActive,
          'requested_first_name': updated.firstName,
          'requested_last_name': updated.lastName,
          'requested_license_number': updated.licenseNumber,
          'requested_specialization': updated.specialization,
          'requested_contact_number': updated.contactNumber,
        },
      );
    }

    if (newPinHash != null) {
      await _db.updateUser(updated, newPinHash: newPinHash);
    } else {
      await _db.updateUser(updated);
    }

    await _auditService.logAction(
      userId: updatedByUserId,
      action: AuditAction.update,
      entityType: 'user',
      entityId: id,
      description: 'Updated user: ${updated.email}',
    );

    return updated;
  }

  // Deactivate user
  Future<void> deactivateUser(String id, String deactivatedByUserId) async {
    await _requireSystemManager(deactivatedByUserId);
    final user = await _db.getUserById(id);
    if (user == null) {
      throw ArgumentError('User not found');
    }

    if (_supabase.auth.currentSession == null) {
      throw StateError(
        'Account deactivation requires an online administrator session',
      );
    }
    await _supabase.rpc(
      'medsentry_update_user_account',
      params: {
        'target_user_id': id,
        'requested_role': user.role.name,
        'requested_active': false,
        'requested_first_name': user.firstName,
        'requested_last_name': user.lastName,
        'requested_license_number': user.licenseNumber,
        'requested_specialization': user.specialization,
        'requested_contact_number': user.contactNumber,
      },
    );

    await _db.deactivateUser(id);

    await _auditService.logAction(
      userId: deactivatedByUserId,
      action: AuditAction.update,
      entityType: 'user',
      entityId: id,
      description: 'Deactivated user: ${user.email}',
    );
  }

  // Change password
  Future<void> changePassword(
    String userId,
    String oldPassword,
    String newPassword,
  ) async {
    final user = await _db.getUserById(userId);
    if (user == null) {
      throw ArgumentError('User not found');
    }

    await _validatePassword(newPassword);
    final authUser = _supabase.auth.currentUser;
    if (authUser == null || authUser.email == null) {
      throw StateError(
        'Password changes require an active Supabase Auth session',
      );
    }
    await _supabase.auth.signInWithPassword(
      email: authUser.email!,
      password: oldPassword,
    );
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    await _supabase.rpc(
      'medsentry_log_auth_event',
      params: {'event_action': 'CHANGE_PASSWORD'},
    );
    await _db.clearUserPasswordHash(userId);

    await _auditService.logAction(
      userId: userId,
      action: AuditAction.passwordChange,
      entityType: 'user',
      entityId: userId,
      description: 'Password changed for user: ${user.email}',
    );
  }

  // Setup PIN
  Future<void> setupPin(String userId, String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be 4 digits');
    }

    final pinHash = _hashPassword(pin);
    await _db.updateUserPin(userId, pinHash, true);

    await _auditService.logAction(
      userId: userId,
      action: AuditAction.pinChange,
      entityType: 'user',
      entityId: userId,
      description: 'PIN enabled for user',
    );
  }

  // Disable PIN
  Future<void> disablePin(String userId) async {
    await _db.updateUserPin(userId, null, false);

    await _auditService.logAction(
      userId: userId,
      action: AuditAction.pinChange,
      entityType: 'user',
      entityId: userId,
      description: 'PIN disabled for user',
    );
  }

  // Alias for authenticate - used by auth provider
  Future<User?> login(String email, String password) async {
    return await authenticate(email, password);
  }

  // Login with PIN - used by auth provider
  Future<User?> loginWithPin(String pin) async {
    // Use the last logged in user ID for PIN login
    final lockedUntil = _pinLockedUntil;
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      final minutes = lockedUntil.difference(DateTime.now()).inMinutes;
      final seconds = lockedUntil.difference(DateTime.now()).inSeconds % 60;
      throw Exception(
        'PIN login locked. Try again in ${minutes}m ${seconds}s.',
      );
    }

    final userId = await _getLastLoggedInUserId();
    if (userId == null) {
      throw Exception('No recent user found for PIN login.');
    }

    debugPrint('Attempting PIN login for user: $userId');
    final isValid = await verifyPin(userId, pin);
    if (!isValid) {
      debugPrint('Invalid PIN');
      _failedPinAttempts++;
      if (_failedPinAttempts >= 5) {
        _pinLockedUntil = DateTime.now().add(const Duration(minutes: 5));
        await _auditService.logAction(
          userId: userId,
          action: AuditAction.login,
          entityType: 'user',
          entityId: userId,
          description: 'Failed PIN login attempt - Account locked',
        );
        throw Exception(
          'Too many failed attempts. PIN login locked for 5 minutes.',
        );
      }
      await _auditService.logAction(
        userId: userId,
        action: AuditAction.login,
        entityType: 'user',
        entityId: userId,
        description: 'Failed PIN login attempt',
      );
      return null;
    }

    final user = await getUserById(userId);
    if (user != null && user.isActive) {
      // Update last login
      await _db.updateUserLastLogin(userId);
      await _setCurrentUserId(userId);
      _failedPinAttempts = 0;
      _pinLockedUntil = null;
      await unlockSession();

      await _auditService.logAction(
        userId: userId,
        action: AuditAction.login,
        entityType: 'user',
        entityId: userId,
        description: 'User logged in with PIN: ${user.email}',
      );

      debugPrint('PIN login successful for: ${user.email}');
    }

    return user?.isActive == true ? user : null;
  }

  // Bypass PIN and login directly after successful hardware biometric verification
  Future<User?> loginWithBiometrics() async {
    final userId = await _getLastLoggedInUserId();
    if (userId == null) {
      throw Exception('No recent user found for biometric login.');
    }

    final user = await getUserById(userId);
    if (user != null && user.isActive) {
      // Update last login
      await _db.updateUserLastLogin(userId);
      await _setCurrentUserId(userId);
      _failedPinAttempts = 0;
      _pinLockedUntil = null;
      await unlockSession();

      await _auditService.logAction(
        userId: userId,
        action: AuditAction.login,
        entityType: 'user',
        entityId: userId,
        description: 'User logged in with Biometrics: ${user.email}',
      );

      debugPrint('Biometric login successful for: ${user.email}');
    }

    return user?.isActive == true ? user : null;
  }

  // Check if PIN login is available (has last logged in user with PIN enabled)
  Future<bool> isPinLoginAvailable() async {
    final userId = await _getLastLoggedInUserId();
    if (userId == null) return false;

    final user = await getUserById(userId);
    return user != null &&
        user.isActive &&
        user.pinEnabled &&
        user.pinHash != null;
  }

  // Get last logged in user email for display
  Future<String?> getLastLoggedInUserEmail() async {
    final userId = await _getLastLoggedInUserId();
    if (userId == null) return null;

    final user = await getUserById(userId);
    return user?.email;
  }

  // Logout — full sign-out; no saved account on the login screen.
  Future<void> logout() async {
    final userId = await _getCurrentUserId() ?? await _getLastLoggedInUserId();

    if (_supabase.auth.currentSession != null) {
      try {
        await _supabase.rpc(
          'medsentry_log_auth_event',
          params: {'event_action': 'LOGOUT'},
        );
      } catch (_) {
        // Sign-out must remain available during network or database outages.
      }
    }
    await _supabase.auth.signOut();
    await _setSessionLocked(false);
    await _clearSession();
    try {
      await _secureStorage.delete(key: _lastUserIdKey);
    } catch (_) {
      // ignore secure storage errors
    }
    await _db.setLastUserId(null);
    _lastLoggedInUserId = null;
    _failedPinAttempts = 0;
    _pinLockedUntil = null;

    if (userId != null) {
      await _auditService.logAction(
        userId: userId,
        action: AuditAction.logout,
        entityType: 'user',
        entityId: userId,
        description: 'User logged out',
      );
    }
  }

  // Lock keeps the last user available for PIN/biometric unlock, but clears the
  // active session so the router shows the unlock screen.
  Future<void> lockSession({String? userId}) async {
    await _clearCurrentUserSession();
    await _setSessionLocked(true);

    if (userId != null) {
      await _auditService.logAction(
        userId: userId,
        action: AuditAction.logout,
        entityType: 'user',
        entityId: userId,
        description: 'User locked the session',
      );
    }
  }

  // Check if user is logged in - used by auth provider
  Future<bool> isLoggedIn() async {
    // Check Supabase auth state
    final session = _supabase.auth.currentSession;
    if (session != null) return true;

    // Fallback to local check
    final user = await getCurrentUser();
    return user != null && user.isActive;
  }

  // Get current user - used by auth provider
  Future<User?> getCurrentUser() async {
    if (await isSessionLocked()) return null;

    // First check Supabase auth
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser != null) {
      final localUser = await _db.getUserByEmail(supabaseUser.email ?? '');
      try {
        final profile = await _supabase
            .from('users')
            .select(
              'id,email,first_name,last_name,role,license_number,specialization,'
              'contact_number,profile_image_url,is_active,pin_enabled,'
              'last_login_at,created_at,updated_at',
            )
            .eq('auth_user_id', supabaseUser.id)
            .maybeSingle();
        if (profile == null) {
          await _supabase.auth.signOut();
          await _clearCurrentUserSession();
          return null;
        }

        final remoteUser = User.fromJson(Map<String, dynamic>.from(profile));
        if (!remoteUser.isActive) {
          await _supabase.auth.signOut();
          await _clearCurrentUserSession();
          return null;
        }

        final currentUser = remoteUser.copyWith(pinHash: localUser?.pinHash);
        if (localUser == null) {
          await _db.insertUser(currentUser);
        } else {
          await _db.updateUser(currentUser);
        }
        await _db.clearUserPasswordHash(currentUser.id);
        return currentUser;
      } catch (_) {
        if (await _isDeviceOffline() && localUser?.isActive == true) {
          return localUser!.copyWith(role: UserRole.staff);
        }
        await _supabase.auth.signOut();
        await _clearCurrentUserSession();
        return null;
      }
    }

    // Fallback to local session
    final userId = await _getCurrentUserId();
    if (userId == null) return null;
    final user = await getUserById(userId);
    return user?.isActive == true ? user : null;
  }

  // Helper methods for session management
  Future<String?> _getCurrentUserId() async {
    try {
      return await _secureStorage.read(key: _currentUserIdKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearSession() async {
    await _clearCurrentUserSession();
    debugPrint('Session cleared');
  }

  Future<void> _clearCurrentUserSession() async {
    try {
      await _secureStorage.delete(key: _currentUserIdKey);
    } catch (_) {}
  }

  Future<void> _requireSystemManager(String userId) async {
    final actor = await _db.getUserById(userId);
    if (actor == null || !actor.isActive || !actor.canManageSystemData) {
      throw StateError('Only an administrator can manage staff accounts');
    }
  }

  void _validateEmail(String email) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      throw ArgumentError('Enter a valid email address');
    }
  }

  void _validateRequiredName(String value, String fieldName) {
    if (value.trim().isEmpty || value.trim().length > 100) {
      throw ArgumentError('$fieldName must be between 1 and 100 characters');
    }
  }

  Future<void> _validatePassword(String password) async {
    final settings = await _db.getSystemSettings();
    final minimumLength = settings.passwordMinLength < 12
        ? 12
        : settings.passwordMinLength;
    if (password.length < minimumLength) {
      throw ArgumentError(
        'Password must be at least $minimumLength characters',
      );
    }
    if (settings.requireStrongPassword &&
        (!RegExp(r'[A-Z]').hasMatch(password) ||
            !RegExp(r'[a-z]').hasMatch(password) ||
            !RegExp(r'\d').hasMatch(password) ||
            !RegExp(r'[^A-Za-z0-9]').hasMatch(password))) {
      throw ArgumentError(
        'Password must include upper- and lower-case letters, a number, and a symbol',
      );
    }
  }
}
