import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_credentials.dart';

/// Single source of truth for cloud auth state. Uses
/// `google_sign_in_all_platforms` so Android (native account picker) and
/// Windows (browser → localhost callback) share the same surface.
///
/// Token JSON persists via SharedPreferences; refresh token survives across
/// launches.
class CloudAuthService {
  CloudAuthService._();
  static final CloudAuthService instance = CloudAuthService._();

  GoogleSignIn? _signIn;
  GoogleSignInCredentials? _credentials;
  String? _userEmail;

  static const _kCredentialsJson = 'cloud_sync_creds_json';
  static const _kUserEmail = 'cloud_sync_user_email';

  /// True once a session has been restored OR `signIn()` has succeeded.
  bool get isSignedIn => _credentials != null;
  String? get userEmail => _userEmail;

  void _ensureSignIn() {
    if (_signIn != null) return;
    if (!CloudCredentials.isConfigured) {
      throw StateError('CloudCredentials not configured');
    }
    _signIn = GoogleSignIn(
      params: GoogleSignInParams(
        clientId: Platform.isAndroid
            ? CloudCredentials.androidClientId
            : CloudCredentials.desktopClientId,
        clientSecret:
            Platform.isAndroid ? null : CloudCredentials.desktopClientSecret,
        scopes: const [CloudCredentials.driveAppDataScope],
        saveAccessToken: _saveAccessToken,
        retrieveAccessToken: _retrieveAccessToken,
        deleteAccessToken: _deleteAccessToken,
      ),
    );
  }

  /// Attempts a silent sign-in using stored credentials. Safe to call on
  /// every app start; never throws.
  Future<void> initSilent() async {
    if (!CloudCredentials.isConfigured) return;
    try {
      _ensureSignIn();
      final creds = await _signIn!.silentSignIn();
      if (creds != null) {
        _credentials = creds;
        final prefs = await SharedPreferences.getInstance();
        _userEmail = prefs.getString(_kUserEmail);
      }
    } catch (e, st) {
      debugPrint('[CloudAuth] silent init failed: $e\n$st');
    }
  }

  /// Interactive sign-in. Pops the platform-native flow (account picker on
  /// Android, browser on Windows). Returns true on success.
  Future<bool> signIn() async {
    if (!CloudCredentials.isConfigured) {
      throw StateError('Cloud sync is not configured');
    }
    _ensureSignIn();
    try {
      final creds = await _signIn!.signIn();
      if (creds == null) return false;
      _credentials = creds;
      return true;
    } catch (e, st) {
      debugPrint('[CloudAuth] signIn failed: $e\n$st');
      rethrow;
    }
  }

  /// Persist the user's email after a successful sign-in. Called from the
  /// service that has the authenticated client.
  Future<void> rememberEmail(String email) async {
    _userEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserEmail, email);
  }

  /// Sign out and forget tokens.
  Future<void> signOut() async {
    if (_signIn != null) {
      try {
        await _signIn!.signOut();
      } catch (e) {
        debugPrint('[CloudAuth] signOut error: $e');
      }
    }
    _credentials = null;
    _userEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCredentialsJson);
    await prefs.remove(_kUserEmail);
  }

  /// Returns an authenticated HTTP client suitable for `googleapis` Drive API.
  /// Returns null if not signed in or token refresh failed.
  Future<http.Client?> authenticatedClient() async {
    if (_signIn == null) return null;
    return _signIn!.authenticatedClient;
  }

  // ── token persistence callbacks for the package ───────────────────────
  // The package serialises creds to a JSON string and hands it to us; we
  // round-trip via SharedPreferences.

  Future<void> _saveAccessToken(String credsJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCredentialsJson, credsJson);
  }

  Future<String?> _retrieveAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCredentialsJson);
  }

  Future<void> _deleteAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCredentialsJson);
  }
}
