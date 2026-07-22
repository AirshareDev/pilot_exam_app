import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../models/qualification.dart';
import '../core/database/bundled_database_installer.dart';
import '../core/database/database_update_policy.dart';

const _catalogAssetPath = 'assets/data/catalog.db';
const _catalogInstalledName = 'catalog.db';

final catalogDatabaseProvider = Provider<CatalogDatabase>((ref) {
  return CatalogDatabase();
});

class CatalogDatabase {
  CatalogDatabase({
    BundledDatabaseInstaller installer = const BundledDatabaseInstaller(),
  }) : _installer = installer;

  final BundledDatabaseInstaller _installer;

  Future<List<Qualification>> loadQualifications({
    bool visibleOnly = true,
    bool enabledOnly = true,
  }) async {
    final db = await _open();
    if (db == null) return const [];

    try {
      final conditions = <String>[];
      final args = <Object?>[];
      if (visibleOnly) {
        conditions.add('q.is_visible = ?');
        args.add(1);
      }
      if (enabledOnly) {
        conditions.add('q.is_enabled = ?');
        args.add(1);
      }

      final rows = await db.rawQuery('''
        SELECT
          q.*,
          c.category_code,
          c.category_name,
          COALESCE(f.has_exam_sessions, 1) AS has_exam_sessions,
          COALESCE(f.has_subjects, 1) AS has_subjects,
          COALESCE(f.has_mock_exam, 1) AS has_mock_exam,
          COALESCE(f.supports_image, 1) AS supports_image,
          COALESCE(f.supports_audio, 0) AS supports_audio,
          COALESCE(f.supports_multiple_answers, 0)
            AS supports_multiple_answers,
          COALESCE(f.max_choices, 5) AS max_choices
        FROM qualifications q
        INNER JOIN qualification_categories c
          ON c.category_id = q.category_id
        LEFT JOIN qualification_features f
          ON f.qualification_id = q.qualification_id
        ${conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}'}
        ORDER BY c.sort_order, q.sort_order, q.qualification_id
      ''', args);

      return rows.map(Qualification.fromMap).toList(growable: false);
    } finally {
      await db.close();
    }
  }

  Future<Qualification?> findByCode(String qualificationCode) async {
    final qualifications = await loadQualifications(
      visibleOnly: false,
      enabledOnly: false,
    );
    for (final qualification in qualifications) {
      if (qualification.code == qualificationCode) return qualification;
    }
    return null;
  }

  Future<Database?> _open() async {
    final path = await _installer.install(
      assetPath: _catalogAssetPath,
      installedFileName: _catalogInstalledName,
      updatePolicy: DatabaseUpdatePolicy.replaceWhenNewer,
    );
    if (path == null) return null;
    return openDatabase(path, readOnly: true);
  }
}
