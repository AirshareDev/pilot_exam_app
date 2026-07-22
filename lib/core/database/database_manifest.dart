import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DatabaseManifest {
  DatabaseManifest._(this._versions);

  static const String assetPath = 'assets/data/database_manifest.json';
  static DatabaseManifest? _cached;

  final Map<String, int> _versions;

  static Future<DatabaseManifest> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    try {
      final source = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('database_manifest.json must be an object.');
      }

      final databases = decoded['databases'];
      if (databases is! Map<String, dynamic>) {
        throw const FormatException('"databases" must be an object.');
      }

      final versions = <String, int>{};
      for (final entry in databases.entries) {
        final value = entry.value;
        if (value is int && value > 0) {
          versions[entry.key] = value;
          continue;
        }
        if (value is Map<String, dynamic>) {
          final version = value['version'];
          if (version is int && version > 0) {
            versions[entry.key] = version;
          }
        }
      }

      return _cached = DatabaseManifest._(Map.unmodifiable(versions));
    } catch (error, stackTrace) {
      debugPrint(
        'Database manifest load failed: $assetPath\n$error\n$stackTrace',
      );
      return _cached = DatabaseManifest._(const {});
    }
  }

  int? versionOf(String fileName) => _versions[fileName];
}
