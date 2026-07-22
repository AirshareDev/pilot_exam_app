enum DatabaseUpdatePolicy {
  /// The bundled database is read-only application data.
  /// Replace the installed copy only when the bundled version is newer.
  replaceWhenNewer,

  /// The installed database contains user data.
  /// Copy it only on first launch and never overwrite it from assets.
  preserveInstalled,
}
