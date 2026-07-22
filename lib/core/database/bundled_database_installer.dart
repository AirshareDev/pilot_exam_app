import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_manifest.dart';
import 'database_update_policy.dart';

class BundledDatabaseInstaller {
  const BundledDatabaseInstaller();

  static const String _versionKeyPrefix = 'installed_database_version.';

  Future<String?> install({
    required String assetPath,
    required String installedFileName,
    DatabaseUpdatePolicy updatePolicy =
        DatabaseUpdatePolicy.replaceWhenNewer,
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, 'database'),
    );
    await databaseDirectory.create(recursive: true);

    final targetFile = File(
      p.join(databaseDirectory.path, installedFileName),
    );
    final targetExists = await targetFile.exists();

    final manifest = await DatabaseManifest.load();
    final bundledVersion = manifest.versionOf(installedFileName);
    final preferences = await SharedPreferences.getInstance();
    final versionKey = '$_versionKeyPrefix$installedFileName';
    final installedVersion = preferences.getInt(versionKey);

    if (updatePolicy == DatabaseUpdatePolicy.preserveInstalled &&
        targetExists) {
      // user.db and similar databases must survive app/data updates.
      // Record the version only as a baseline; never replace user data.
      if (installedVersion == null && bundledVersion != null) {
        await preferences.setInt(versionKey, bundledVersion);
      }
      return targetFile.path;
    }

    final shouldInstall = !targetExists ||
        (updatePolicy == DatabaseUpdatePolicy.replaceWhenNewer &&
            _isBundledDatabaseNewer(
              bundledVersion: bundledVersion,
              installedVersion: installedVersion,
            ));

    if (!shouldInstall) {
      return targetFile.path;
    }

    final bytes = await _loadAssetBytes(assetPath);
    if (bytes == null) return targetExists ? targetFile.path : null;

    try {
      await _replaceAtomically(targetFile, bytes);
      if (bundledVersion != null) {
        await preferences.setInt(versionKey, bundledVersion);
      }
      debugPrint(
        'Database installed: $installedFileName '
        '(version ${bundledVersion ?? 'unmanaged'})',
      );
      return targetFile.path;
    } catch (error, stackTrace) {
      debugPrint(
        'Database install failed: $installedFileName\n$error\n$stackTrace',
      );
      return targetExists ? targetFile.path : null;
    }
  }

  bool _isBundledDatabaseNewer({
    required int? bundledVersion,
    required int? installedVersion,
  }) {
    // A manifest entry is required for automatic replacement.
    if (bundledVersion == null) return false;

    // Existing installations created before version management have no
    // recorded version. Replace their read-only DB once and establish a
    // baseline without requiring an uninstall.
    if (installedVersion == null) return true;

    return bundledVersion > installedVersion;
  }

  Future<Uint8List?> _loadAssetBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Database asset load failed: $assetPath\n$error\n$stackTrace',
      );
      return null;
    }
  }

  Future<void> _replaceAtomically(File targetFile, Uint8List bytes) async {
    final temporaryFile = File('${targetFile.path}.tmp');
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    await temporaryFile.writeAsBytes(bytes, flush: true);

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await temporaryFile.rename(targetFile.path);
  }
}
