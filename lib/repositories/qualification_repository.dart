import '../database/catalog_database.dart';
import '../models/qualification.dart';

/// Compatibility wrapper for older callers.
/// New code may use [CatalogDatabase] directly.
class QualificationRepository {
  const QualificationRepository(this._database);

  final CatalogDatabase _database;

  Future<List<Qualification>> loadQualifications() {
    return _database.loadQualifications();
  }
}
