/// OAuth 2.0 credentials for Google Drive sync.
///
/// Replace the placeholder values with real OAuth client IDs created in
/// Google Cloud Console for the project tied to this app:
///   - Desktop client (used on Windows): exposes client id + secret
///   - Android client (used on Android via the platform plugin):
///     exposes only client id; SHA-1 of the signing keystore is bound to
///     the client in the GCP console
///
/// See `docs/cloud-sync-setup.md` for the full setup procedure.
class CloudCredentials {
  CloudCredentials._();

  // TODO(setup): replace before shipping. Until replaced, sync UI shows
  // a "not configured" state instead of crashing.
  static const String desktopClientId =
      'REPLACE_WITH_DESKTOP_CLIENT_ID.apps.googleusercontent.com';
  static const String desktopClientSecret = 'REPLACE_WITH_DESKTOP_CLIENT_SECRET';
  static const String androidClientId =
      'REPLACE_WITH_ANDROID_CLIENT_ID.apps.googleusercontent.com';

  /// Returns true once real credentials have been wired in. The sync UI
  /// uses this to gate the "Connect" button.
  static bool get isConfigured =>
      !desktopClientId.startsWith('REPLACE_WITH_') &&
      !desktopClientSecret.startsWith('REPLACE_WITH_') &&
      !androidClientId.startsWith('REPLACE_WITH_');

  /// `drive.appdata` keeps the database file private to this app — invisible
  /// in the user's normal Drive view, auto-deleted on uninstall+reinstall is
  /// not an issue because the same Google account preserves the folder.
  static const String driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
}
