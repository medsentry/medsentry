import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';

import '../config/seed_credentials.dart';
import '../database/simple_database.dart';
import '../models/audit_log.dart';
import '../models/login_challenge.dart';
import '../models/user.dart';
import '../services/audit_service.dart';
import '../utils/password_crypto.dart';
import 'otp_gateway.dart';

class AuthRepository {
  static const String _legacyStaffEmail = 'staff@rhu.gov.ph';
  static const bool _allowDefaultAdmin = bool.fromEnvironment(
    'MEDSENTRY_ALLOW_DEFAULT_ADMIN',
    defaultValue: true,
  );
  static const String _currentUserIdKey = 'medsentry.current_user_id';
  static const String _lastUserIdKey = 'medsentry.last_user_id';
  static const String _sessionLockedKey = 'medsentry.session_locked';
  static const String _otpVerifiedAtKey = 'medsentry.otp_verified_at';

  final SimpleDatabase _db;
  final AuditService _auditService;
  final OtpGateway _otp;
  late final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  // Store last logged in user ID for PIN login
  String? _lastLoggedInUserId;
  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  AuthRepository(this._db, this._auditService, {OtpGateway? otpGateway})
    : _otp = otpGateway ?? SupabaseOtpGateway();


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
    final staffAccount = SeedCredentials.accounts
        .where((a) => a.email == 'staff@gmail.com')
        .firstOrNull;
    if (staffAccount == null) return;
    final existingStaff = await _db.getUserByEmail(staffAccount.email);
    if (existingStaff != null) return;

    await _db.updateUser(
      legacyUser.copyWith(email: staffAccount.email, updatedAt: DateTime.now()),
    );
  }

  Future<User> _ensureSeedAccount(SeedAccount account) async {
    final existingUser = await _db.getUserByEmail(account.email);
    if (existingUser != null) {
      if (existingUser.clinicId == null && account.clinicId != null) {
        final updatedUser = existingUser.copyWith(
          clinicId: account.clinicId,
          updatedAt: DateTime.now(),
        );
        await _db.updateUser(updatedUser);
        return updatedUser;
      }
      final existingHash = await _db.getUserPasswordHash(existingUser.id);
      if (existingHash == null) {
        await _db.updateUserPassword(existingUser.id, _getSeedPasswordHash());
      }
      return existingUser;
    }

    final now = DateTime.now();
    final passwordHash = _getSeedPasswordHash();

    final user = User(
      id: account.id,
      clinicId: account.clinicId,
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

  /// The built-in development password only ever unlocks the Super Admin seed
  /// account, and only in debug builds. Staff and RHU Admin always go through
  /// the online password + email OTP flow.
  bool _isSeedShortcut(SeedAccount account, String password) {
    if (!kDebugMode || !_allowDefaultAdmin) return false;
    if (account.role != UserRole.superAdmin) return false;
    return password == SeedCredentials.defaultPassword ||
        password == 'Password123!';
  }

  Future<void> ensureOnlineSession() async {
    // A local session must never acquire a privileged Supabase session using
    // seeded credentials. Online authentication happens only after explicit
    // user sign-in.
    if (_supabase.auth.currentSession != null) return;
  }

  // Create new user
  Future<User> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? clinicId,
    String? licenseNumber,
    String? specialization,
    String? contactNumber,
    String? profileImageUrl,
    bool pinEnabled = false,
    String? pin,
    required String createdByUserId,
  }) async {
    await _requireSystemManager(createdByUserId);
    final creator = await _db.getUserById(createdByUserId);
    if (creator != null && !creator.isSuperAdmin) {
      if (role == UserRole.superAdmin) {
        throw StateError('Only a super administrator can create this role');
      }
      if (creator.clinicId == null ||
          (clinicId != null && clinicId != creator.clinicId)) {
        throw StateError('User accounts must remain within your RHU');
      }
      clinicId = creator.clinicId;
    }
    _validateEmail(email);
    _validateRequiredName(firstName, 'First name');
    _validateRequiredName(lastName, 'Last name');
    await _validatePassword(password);

    if (role != UserRole.superAdmin &&
        (clinicId == null || clinicId.trim().isEmpty)) {
      throw ArgumentError(
        'A clinic facility must be assigned for ${role.name} accounts',
      );
    }
    if (role == UserRole.superAdmin) {
      clinicId = null;
    }

    if (pinEnabled && (pin == null || !RegExp(r'^\d{4}$').hasMatch(pin))) {
      throw ArgumentError('Enabled PIN must be exactly 4 digits');
    }
    final pinHash = pinEnabled ? _hashPassword(pin!) : null;

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();
    final existingUser = await _db.getUserByEmail(normalizedEmail);
    if (existingUser != null) {
      throw ArgumentError('Email already exists');
    }

    // Try to ensure an active Supabase online session if possible
    await ensureOnlineSession();

    String? remoteUserId;
    bool provisionedOnline = false;

    if (_supabase.auth.currentSession != null) {
      try {
        final response = await _supabase.functions.invoke(
          'provision-user',
          body: {
            'action': 'create',
            'email': normalizedEmail,
            'password': password,
            'first_name': normalizedFirstName,
            'last_name': normalizedLastName,
            'role': role.dbValue,
            'clinic_id': clinicId,
            'license_number': licenseNumber,
            'specialization': specialization,
            'contact_number': contactNumber,
          },
        );
        if (response.data is Map) {
          final profile = Map<String, dynamic>.from(response.data as Map);
          remoteUserId = profile['id'] as String?;
          provisionedOnline = remoteUserId != null;
        }
      } on FunctionException catch (e) {
        debugPrint(
          'AuthRepository: FunctionException during provision-user: ${e.status} ${e.details}',
        );
        final details = e.details;
        String? message;
        if (details is Map && details['error'] != null) {
          message = details['error'].toString();
        } else {
          message = details?.toString();
        }
        final lower = (message ?? '').toLowerCase();
        if (lower.contains('already') ||
            lower.contains('duplicate') ||
            lower.contains('exists')) {
          throw ArgumentError(
            message ?? 'A user with this email already exists.',
          );
        }
        if (lower.contains('required') || lower.contains('invalid')) {
          throw ArgumentError(message ?? 'Invalid account details.');
        }
      } catch (e) {
        debugPrint('AuthRepository: online provisioning error: $e');
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('already registered') ||
            errStr.contains('already exists')) {
          throw ArgumentError('Email already exists in remote database');
        }
      }
    }

    final id = remoteUserId ?? _uuid.v4();
    final now = DateTime.now();
    final passwordHash = _hashPassword(password);

    final user = User(
      id: id,
      clinicId: clinicId,
      email: normalizedEmail,
      firstName: normalizedFirstName,
      lastName: normalizedLastName,
      role: role,
      licenseNumber: licenseNumber,
      specialization: specialization,
      contactNumber: contactNumber,
      profileImageUrl: profileImageUrl,
      isActive: true,
      pinEnabled: pinEnabled,
      pinHash: pinHash,
      createdAt: now,
      updatedAt: now,
      syncStatus: provisionedOnline ? 0 : 1,
    );

    if (clinicId != null && provisionedOnline) {
      try {
        await _supabase
            .from('users')
            .update({'clinic_id': clinicId})
            .eq('id', id);
      } catch (e) {
        debugPrint(
          'AuthRepository: failed to set clinic_id on remote user: $e',
        );
      }
    }

    if (pinEnabled && pin != null && pin.isNotEmpty && provisionedOnline) {
      await _setPinOnline(id, pin, enabled: true);
    }

    await _db.insertUser(user, passwordHash: passwordHash);

    await _auditService.logAction(
      userId: createdByUserId,
      action: AuditAction.create,
      entityType: 'user',
      entityId: id,
      description:
          'Created user: $normalizedEmail with role ${role.name}${provisionedOnline ? ' (online)' : ' (offline pending sync)'}',
    );

    return user;
  }

  // Authenticate user with email and password using Supabase or a local account.
  Future<User?> authenticate(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();

    // 1. Direct seed account verification (Super Admin) - instant login
    final seedAccount = _seedAccountForEmail(normalizedEmail);
    if (seedAccount != null && _isSeedShortcut(seedAccount, password)) {
      final user = await _ensureSeedAccount(seedAccount);
      await _db.updateUserLastLogin(user.id);
      await _setCurrentUserId(user.id);
      await unlockSession();

      // Sign in to Supabase in background without blocking UI
      unawaited(() async {
        try {
          await _supabase.auth
              .signInWithPassword(email: normalizedEmail, password: password)
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('Supabase background auth warning: $e');
          await ensureOnlineSession();
        }
      }());

      return user;
    }

    // 2. Fast-path: Check local offline database first for instant login
    final localUser = await _authenticateLocal(normalizedEmail, password);
    if (localUser != null) {
      // Authenticated locally! Sync session with Supabase in background
      unawaited(() async {
        try {
          await _supabase.auth
              .signInWithPassword(email: normalizedEmail, password: password)
              .timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('Supabase background auth warning: $e');
          await ensureOnlineSession();
        }
      }());
      return localUser;
    }

    // 3. Fall back to online Supabase with strict timeout
    try {
      final response = await _supabase.auth
          .signInWithPassword(email: normalizedEmail, password: password)
          .timeout(const Duration(seconds: 3));

      if (response.user == null) {
        return null;
      }

      final cachedUser = await _db.getUserByEmail(normalizedEmail);
      final profile = await _supabase
          .from('users')
          .select(
            'id,clinic_id,email,first_name,last_name,role,license_number,specialization,'
            'contact_number,profile_image_url,is_active,pin_enabled,'
            'last_login_at,created_at,updated_at',
          )
          .eq('auth_user_id', response.user!.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));

      if (profile == null) {
        unawaited(_supabase.auth.signOut().catchError((_) {}));
        return null;
      }

      final serverUser = User.fromJson(Map<String, dynamic>.from(profile));
      final mergedUser = serverUser.copyWith(pinHash: cachedUser?.pinHash);
      if (!mergedUser.isActive) {
        unawaited(_supabase.auth.signOut().catchError((_) {}));
        return null;
      }
      if (mergedUser.requiresEmailOtp) {
        // Password alone is never enough for these roles; use beginLogin().
        unawaited(_supabase.auth.signOut().catchError((_) {}));
        return null;
      }

      unawaited(
        _supabase
            .rpc('medsentry_log_auth_event', params: {'event_action': 'LOGIN'})
            .catchError(
              (e) => debugPrint('medsentry_log_auth_event non-fatal: $e'),
            ),
      );

      if (cachedUser == null) {
        await _db.insertUser(mergedUser);
      } else {
        await _db.updateUser(mergedUser);
      }
      await _db.updateUserPassword(mergedUser.id, _hashPassword(password));

      await _db.updateUserLastLogin(mergedUser.id);

      await _auditService.logAction(
        userId: mergedUser.id,
        action: AuditAction.login,
        entityType: 'user',
        entityId: mergedUser.id,
        description: 'User logged in: $normalizedEmail',
      );

      // Store the user ID for PIN login
      await _setCurrentUserId(mergedUser.id);
      await unlockSession();
      return mergedUser;
    } on AuthException catch (e) {
      debugPrint('AuthException during login: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Login exception: $e');
      return null;
    }
  }

  Future<User?> _authenticateLocal(
    String normalizedEmail,
    String password,
  ) async {
    final seed = _seedAccountForEmail(normalizedEmail);
    if (seed != null && _isSeedShortcut(seed, password)) {
      final user = await _ensureSeedAccount(seed);
      await _db.updateUserLastLogin(user.id);
      await _setCurrentUserId(user.id);
      await unlockSession();
      return user;
    }

    final localUser = await _db.getUserByEmail(normalizedEmail);
    if (localUser == null || !localUser.isActive) return null;
    // Staff and RHU Admin must always verify by email OTP (see beginLogin).
    if (localUser.requiresEmailOtp) return null;

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

    if (!user.pinEnabled) return false;
    if (user.pinHash != null) {
      if (_supabase.auth.currentSession == null) {
        return _verifyPassword(pin, user.pinHash!);
      }

      try {
        final result = await _supabase.rpc(
          'medsentry_verify_user_pin',
          params: {'target_user_id': userId, 'requested_pin': pin},
        );
        if (result == 'verified') return true;
        if (result != 'not_configured') return false;
      } catch (error) {
        debugPrint(
          'Online PIN verification unavailable; using local PIN: $error',
        );
      }
      return _verifyPassword(pin, user.pinHash!);
    }

    await ensureOnlineSession();
    if (_supabase.auth.currentSession == null) {
      throw StateError('Connect to the internet to verify this PIN.');
    }
    final result = await _supabase.rpc(
      'medsentry_verify_user_pin',
      params: {'target_user_id': userId, 'requested_pin': pin},
    );
    if (result == 'verified') {
      await _db.updateUserPin(userId, _hashPassword(pin), true);
      return true;
    }
    return false;
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
    String? clinicId,
    String? firstName,
    String? lastName,
    String? licenseNumber,
    String? contactNumber,
    String? specialization,
    String? profileImageUrl,
    UserRole? role,
    bool? isActive,
    bool? isReactivated,
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
    if (actor.id != id && !actor.canManageStaffAccounts) {
      throw StateError('You are not allowed to update this account');
    }
    if (!actor.isSuperAdmin) {
      if (existing.role == UserRole.superAdmin || role == UserRole.superAdmin) {
        throw StateError('Only a super administrator can manage this role');
      }
      if (existing.clinicId != actor.clinicId ||
          (clinicId != null && clinicId != actor.clinicId)) {
        throw StateError('User accounts must remain within your RHU');
      }
    }
    if (actor.id == id && changesAccess && !actor.canManageStaffAccounts) {
      throw StateError('Only an administrator can change account access');
    }

    if (newPassword != null && newPassword.isNotEmpty) {
      await _validatePassword(newPassword);
      await ensureOnlineSession();
      if (_supabase.auth.currentSession != null) {
        try {
          await _supabase.functions.invoke(
            'provision-user',
            body: {
              'action': 'set_password',
              'target_user_id': id,
              'password': newPassword,
            },
          );
        } catch (e) {
          debugPrint('Remote password update failed: $e');
        }
      }
      await _db.updateUserPassword(id, _hashPassword(newPassword));
    }

    // Hash new PIN if provided
    String? newPinHash;
    if (newPin != null && newPin.isNotEmpty) {
      if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
        throw ArgumentError('PIN must be 4 digits');
      }
      newPinHash = _hashPassword(newPin);
    }

    final willReactivate = existing.isActive == false && (isActive == true);
    final updated = existing.copyWith(
      clinicId: clinicId ?? existing.clinicId,
      firstName: firstName ?? existing.firstName,
      lastName: lastName ?? existing.lastName,
      licenseNumber: licenseNumber ?? existing.licenseNumber,
      contactNumber: contactNumber ?? existing.contactNumber,
      specialization: specialization ?? existing.specialization,
      profileImageUrl: profileImageUrl ?? existing.profileImageUrl,
      role: role ?? existing.role,
      isActive: isActive ?? existing.isActive,
      isReactivated: willReactivate
          ? true
          : (isReactivated ??
                (existing.isReactivated && (isActive ?? existing.isActive))),
      pinEnabled: pinEnabled ?? existing.pinEnabled,
      updatedAt: DateTime.now(),
      syncStatus: existing.syncStatus == 0 ? 2 : existing.syncStatus,
    );

    if (clinicId != null && clinicId != existing.clinicId) {
      try {
        await _supabase
            .from('users')
            .update({'clinic_id': clinicId})
            .eq('id', id);
      } catch (e) {
        debugPrint(
          'AuthRepository: failed to update clinic_id on remote user: $e',
        );
      }
    }

    final accountChanged =
        updated.firstName != existing.firstName ||
        updated.lastName != existing.lastName ||
        updated.licenseNumber != existing.licenseNumber ||
        updated.contactNumber != existing.contactNumber ||
        updated.specialization != existing.specialization ||
        updated.role != existing.role ||
        updated.isActive != existing.isActive;

    if (accountChanged) {
      await ensureOnlineSession();
      if (_supabase.auth.currentSession != null) {
        try {
          await _supabase.rpc(
            'medsentry_update_user_account',
            params: {
              'target_user_id': id,
              'requested_role': updated.role.dbValue,
              'requested_active': updated.isActive,
              'requested_first_name': updated.firstName,
              'requested_last_name': updated.lastName,
              'requested_license_number': updated.licenseNumber,
              'requested_specialization': updated.specialization,
              'requested_contact_number': updated.contactNumber,
            },
          );
        } catch (e) {
          debugPrint('Remote account update non-fatal: $e');
        }
      }
    }

    if (newPinHash != null) {
      await _setPinOnline(id, newPin!, enabled: true);
      await _db.updateUser(updated, newPinHash: newPinHash);
    } else {
      if (pinEnabled == false && existing.pinEnabled) {
        await _setPinOnline(id, null, enabled: false);
      }
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

    await ensureOnlineSession();
    if (_supabase.auth.currentSession != null) {
      try {
        await _supabase.rpc(
          'medsentry_update_user_account',
          params: {
            'target_user_id': id,
            'requested_role': user.role.dbValue,
            'requested_active': false,
            'requested_first_name': user.firstName,
            'requested_last_name': user.lastName,
            'requested_license_number': user.licenseNumber,
            'requested_specialization': user.specialization,
            'requested_contact_number': user.contactNumber,
          },
        );
      } catch (e) {
        debugPrint('Remote deactivation warning: $e');
      }
    }

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

  /// Triggers an administrative password reset for a subordinate or user account.
  /// Accessible by both Admin and Super Admin roles according to RBAC scope.
  Future<void> adminResetUserPassword({
    required String targetUserId,
    required String newPassword,
    required String actorUserId,
  }) async {
    final actor = await _db.getUserById(actorUserId);
    if (actor == null || !actor.isActive) {
      throw StateError('An active user session is required to reset passwords');
    }
    if (!actor.canResetUserPasswords) {
      throw StateError('You are not authorized to reset user passwords');
    }

    final target = await _db.getUserById(targetUserId);
    if (target == null) {
      throw ArgumentError('Target user not found');
    }

    if (!actor.isSuperAdmin) {
      if (target.isSuperAdmin) {
        throw StateError(
          'Administrators cannot reset Super Administrator passwords',
        );
      }
      if (target.clinicId != null &&
          actor.clinicId != null &&
          target.clinicId != actor.clinicId) {
        throw StateError(
          'You can only reset passwords for accounts within your RHU facility',
        );
      }
    }

    await _validatePassword(newPassword);
    await ensureOnlineSession();

    if (_supabase.auth.currentSession != null) {
      try {
        await _supabase.functions.invoke(
          'provision-user',
          body: {
            'action': 'set_password',
            'target_user_id': targetUserId,
            'password': newPassword,
          },
        );
      } catch (e) {
        debugPrint('Remote password reset warning: $e');
      }
    }

    await _db.updateUserPassword(targetUserId, _hashPassword(newPassword));

    await _auditService.logAction(
      userId: actorUserId,
      action: AuditAction.passwordChange,
      entityType: 'user',
      entityId: targetUserId,
      description:
          'Administrative password reset for user: ${target.email} by ${actor.roleDisplay} ${actor.fullName}',
    );
  }

  // Setup PIN
  Future<void> setupPin(String userId, String pin) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw ArgumentError('PIN must be 4 digits');
    }

    await _setPinOnline(userId, pin, enabled: true);
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
    await _setPinOnline(userId, null, enabled: false);
    await _db.updateUserPin(userId, null, false);

    await _auditService.logAction(
      userId: userId,
      action: AuditAction.pinChange,
      entityType: 'user',
      entityId: userId,
      description: 'PIN disabled for user',
    );
  }

  Future<void> _setPinOnline(
    String userId,
    String? pin, {
    required bool enabled,
  }) async {
    await ensureOnlineSession();
    if (_supabase.auth.currentSession == null) {
      throw StateError('Connect to the internet to save this PIN online.');
    }
    await _supabase.rpc(
      'medsentry_set_user_pin',
      params: {
        'target_user_id': userId,
        'requested_pin': pin,
        'requested_enabled': enabled,
      },
    );
  }

  static const String _offlineMessage =
      'Internet connection required. Staff and RHU Admin accounts must verify '
      'their email with a one-time code, so please connect and try again.';

  bool _isNetworkError(Object e) {
    if (e is TimeoutException || e is AuthRetryableFetchException) return true;
    final text = e.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('XMLHttpRequest');
  }

  /// Phase one of login (email + password).
  ///
  /// Super Admin signs in directly. Staff and RHU Admin are verified online,
  /// the temporary session is discarded, and a one-time code is emailed; no
  /// session exists until [verifyLoginOtp] succeeds, so the gate is enforced by
  /// the server rather than only by the UI.
  Future<LoginResult> beginLogin(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final localUser = await _db.getUserByEmail(normalizedEmail);

    if (localUser != null && !localUser.requiresEmailOtp) {
      final user = await authenticate(normalizedEmail, password);
      if (user == null) return const LoginFailure('Invalid email or password.');
      unawaited(ensureOnlineSession());
      return LoginSuccess(user);
    }
    if (localUser != null && !localUser.isActive) {
      return const LoginFailure('This account is inactive.');
    }

    try {
      final authUserId = await _otp.verifyPassword(normalizedEmail, password);
      final profile = await _otp.fetchProfile(authUserId);
      if (profile == null) {
        await _otp.signOutLocal();
        return const LoginFailure('Invalid email or password.');
      }
      final serverUser = User.fromJson(profile);
      if (!serverUser.isActive) {
        await _otp.signOutLocal();
        return const LoginFailure('This account is inactive.');
      }
      if (!serverUser.requiresEmailOtp) {
        // Super Admin without a local record yet: session already established.
        final user = await _finishOnlineLogin(serverUser, method: 'password');
        return LoginSuccess(user);
      }

      // Password verified. Drop the session until the emailed code is proven.
      await _otp.signOutLocal();
      return await _sendChallenge(serverUser.email, serverUser.id);
    } on AuthException catch (e) {
      debugPrint('beginLogin AuthException: ${e.message}');
      if (_isNetworkError(e)) {
        return const LoginFailure(_offlineMessage, isNetworkError: true);
      }
      return const LoginFailure('Invalid email or password.');
    } catch (e) {
      debugPrint('beginLogin error: $e');
      if (_isNetworkError(e)) {
        return const LoginFailure(_offlineMessage, isNetworkError: true);
      }
      return const LoginFailure('Login failed. Please try again.');
    }
  }

  Future<LoginResult> _sendChallenge(
    String email,
    String userId, {
    int attemptsLeft = kOtpMaxAttempts,
  }) async {
    try {
      await _otp.sendOtp(email);
    } on AuthException catch (e) {
      debugPrint('sendOtp AuthException: ${e.statusCode} ${e.message}');
      final rateLimited =
          e.statusCode == '429' || e.message.toLowerCase().contains('seconds');
      return LoginFailure(
        rateLimited
            ? 'A code was sent recently. Please wait a minute before trying again.'
            : 'We could not send the verification email. Please contact your administrator.',
      );
    } catch (e) {
      if (_isNetworkError(e)) {
        return const LoginFailure(_offlineMessage, isNetworkError: true);
      }
      return const LoginFailure('We could not send the verification email.');
    }

    final now = DateTime.now();
    await _auditService.logAction(
      userId: userId,
      action: AuditAction.login,
      entityType: 'user',
      entityId: userId,
      description: 'Email verification code sent to ${_maskedEmail(email)}',
    );
    return LoginOtpRequired(
      OtpChallenge(
        email: email,
        maskedEmail: _maskedEmail(email),
        expiresAt: now.add(kOtpLifetime),
        resendAvailableAt: now.add(kOtpResendCooldown),
        attemptsLeft: attemptsLeft,
      ),
    );
  }

  String _maskedEmail(String email) => OtpChallenge.maskEmail(email);

  /// Requests a fresh code once the resend cooldown has elapsed.
  Future<LoginResult> resendLoginOtp(OtpChallenge challenge) async {
    if (challenge.resendWait > Duration.zero) {
      return LoginFailure(
        'Please wait ${challenge.resendWait.inSeconds}s before requesting another code.',
      );
    }
    final user = await _db.getUserByEmail(challenge.email);
    return _sendChallenge(challenge.email, user?.id ?? 'system');
  }

  /// Phase two of login: verifies the emailed code and opens the session.
  Future<OtpVerifyResult> verifyLoginOtp(
    OtpChallenge challenge,
    String code,
  ) async {
    final trimmed = code.trim();
    if (challenge.isExpired) {
      return OtpRejected(
        'This code has expired. Request a new one.',
        challenge: challenge,
      );
    }
    if (!RegExp('^\\d{$kOtpLength}\$').hasMatch(trimmed)) {
      return OtpRejected(
        'Enter the $kOtpLength-digit code.',
        challenge: challenge,
      );
    }

    final localUser = await _db.getUserByEmail(challenge.email);
    try {
      final authUserId = await _otp.verifyOtp(challenge.email, trimmed);
      final profile = await _otp.fetchProfile(authUserId);
      if (profile == null) {
        await _otp.signOutLocal();
        return const OtpRejected(
          'Account not found.',
          exhausted: true,
        );
      }
      final serverUser = User.fromJson(profile);
      if (!serverUser.isActive || !serverUser.requiresEmailOtp) {
        await _otp.signOutLocal();
        return const OtpRejected(
          'This account cannot sign in.',
          exhausted: true,
        );
      }
      final user = await _finishOnlineLogin(
        serverUser,
        method: 'password + email code',
        cachedPinHash: localUser?.pinHash,
      );
      return OtpVerified(user);
    } on AuthException catch (e) {
      debugPrint('verifyLoginOtp AuthException: ${e.message}');
      if (_isNetworkError(e)) {
        return OtpRejected(_offlineMessage, challenge: challenge);
      }
      final left = challenge.attemptsLeft - 1;
      await _auditService.logAction(
        userId: localUser?.id ?? 'system',
        action: AuditAction.login,
        entityType: 'user',
        entityId: localUser?.id ?? 'system',
        description: 'Failed email code verification for ${challenge.email}',
      );
      if (left <= 0) {
        return const OtpRejected(
          'Too many incorrect codes. Please sign in again.',
          exhausted: true,
        );
      }
      return OtpRejected(
        'Incorrect code. $left attempt${left == 1 ? '' : 's'} left.',
        challenge: challenge.copyWith(attemptsLeft: left),
      );
    } catch (e) {
      debugPrint('verifyLoginOtp error: $e');
      return OtpRejected(
        _isNetworkError(e)
            ? _offlineMessage
            : 'Verification failed. Please try again.',
        challenge: challenge,
      );
    }
  }

  /// Persists the verified server profile locally and opens the app session.
  Future<User> _finishOnlineLogin(
    User serverUser, {
    required String method,
    String? cachedPinHash,
  }) async {
    final cached = await _db.getUserByEmail(serverUser.email);
    final merged = serverUser.copyWith(
      pinHash: cachedPinHash ?? cached?.pinHash,
      clinicId: serverUser.clinicId ?? cached?.clinicId,
    );
    if (cached == null) {
      await _db.insertUser(merged);
    } else {
      await _db.updateUser(merged);
    }
    await _db.updateUserLastLogin(merged.id);
    await _setCurrentUserId(merged.id);
    await unlockSession();
    if (merged.requiresEmailOtp) {
      await _markOtpVerified();
    }
    unawaited(_otp.logLoginEvent());
    await _auditService.logAction(
      userId: merged.id,
      action: AuditAction.login,
      entityType: 'user',
      entityId: merged.id,
      description: 'User logged in ($method): ${merged.email}',
    );
    return merged;
  }

  Future<void> _markOtpVerified() async {
    try {
      await _secureStorage.write(
        key: _otpVerifiedAtKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Secure storage may be unavailable; fall back to disk.
    }
    await _db.setOtpVerifiedAt(DateTime.now());
  }

  Future<void> _clearOtpVerified() async {
    try {
      await _secureStorage.delete(key: _otpVerifiedAtKey);
    } catch (_) {}
    await _db.setOtpVerifiedAt(null);
  }

  /// PIN / biometric unlock resumes an existing session. For Staff and RHU
  /// Admin it is only honoured while a live, OTP-verified session exists and
  /// the code was confirmed within [kOtpTrustWindow].
  Future<bool> _isOtpTrustValid(User user) async {
    if (!user.requiresEmailOtp) return true;
    if (!_otp.hasSession) return false;
    DateTime? verifiedAt;
    var secureStorageFailed = false;
    try {
      final raw = await _secureStorage.read(key: _otpVerifiedAtKey);
      if (raw != null) verifiedAt = DateTime.tryParse(raw);
    } catch (_) {
      secureStorageFailed = true;
    }
    if (secureStorageFailed) verifiedAt = await _db.getOtpVerifiedAt();
    if (verifiedAt == null) return false;
    return DateTime.now().difference(verifiedAt) <= kOtpTrustWindow;
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
    final pinUser = await getUserById(userId);
    if (pinUser != null && !await _isOtpTrustValid(pinUser)) {
      throw Exception(
        'Email verification expired. Please sign in with your password.',
      );
    }
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
      unawaited(ensureOnlineSession());

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
    if (user != null && !await _isOtpTrustValid(user)) {
      throw Exception(
        'Email verification expired. Please sign in with your password.',
      );
    }
    if (user != null && user.isActive) {
      // Update last login
      await _db.updateUserLastLogin(userId);
      await _setCurrentUserId(userId);
      _failedPinAttempts = 0;
      _pinLockedUntil = null;
      await unlockSession();
      unawaited(ensureOnlineSession());

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
    if (user == null || !user.isActive || !user.pinEnabled) return false;
    if (!await _isOtpTrustValid(user)) return false;
    if (user.pinHash != null) return true;

    await ensureOnlineSession();
    return _supabase.auth.currentSession != null;
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
    await _clearOtpVerified();
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

    // Check local session first
    final userId = await _getCurrentUserId();
    User? localUser;
    if (userId != null) {
      localUser = await getUserById(userId);
      if (localUser != null && !localUser.isActive) {
        await _clearCurrentUserSession();
        return null;
      }
    }

    // Check Supabase auth if session exists, but protect with strict timeout
    final supabaseUser = _supabase.auth.currentUser;
    if (supabaseUser != null) {
      if (userId == null) {
        await _supabase.auth.signOut();
        return null;
      }
      if (localUser != null &&
          localUser.email.toLowerCase() !=
              (supabaseUser.email ?? '').toLowerCase()) {
        await _supabase.auth.signOut();
        return localUser.isActive ? localUser : null;
      }
      final candidateUser = localUser;

      try {
        final profile = await _supabase
            .from('users')
            .select(
              'id,clinic_id,email,first_name,last_name,role,license_number,specialization,'
              'contact_number,profile_image_url,is_active,pin_enabled,'
              'last_login_at,created_at,updated_at',
            )
            .eq('auth_user_id', supabaseUser.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        if (profile != null) {
          final remoteUser = User.fromJson(Map<String, dynamic>.from(profile));
          if (localUser == null || remoteUser.id != localUser.id) {
            await _supabase.auth.signOut();
            return localUser?.isActive == true ? localUser : null;
          }
          if (!remoteUser.isActive) {
            unawaited(_supabase.auth.signOut().catchError((_) {}));
            await _clearCurrentUserSession();
            return null;
          }

          final currentUser = remoteUser.copyWith(
            clinicId: remoteUser.clinicId ?? candidateUser?.clinicId,
            pinHash: candidateUser?.pinHash,
          );
          await _db.updateUser(currentUser);
          return currentUser;
        }
      } catch (e) {
        debugPrint('Supabase getCurrentUser profile lookup non-fatal: $e');
      }

      // If remote profile fetch timed out or failed, fall back safely to cached user
      if (candidateUser != null && candidateUser.isActive) {
        return candidateUser;
      }
    }

    // Fallback to local session
    if (localUser != null && localUser.isActive) {
      return localUser;
    }

    return null;
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
    if (userId == 'system') return;
    final actor = await _db.getUserById(userId);
    if (actor == null) {
      final seed = SeedCredentials.accounts
          .where((a) => a.id == userId)
          .firstOrNull;
      if (seed != null &&
          (seed.role == UserRole.superAdmin || seed.role == UserRole.admin)) {
        return;
      }
      throw StateError('Only an administrator can manage user accounts');
    }
    if (!actor.isActive || !actor.canManageSystemData) {
      throw StateError('Only an administrator can manage user accounts');
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
    final minimumLength = settings.passwordMinLength < 8
        ? 8
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
