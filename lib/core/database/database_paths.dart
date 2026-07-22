class DatabasePaths {
  const DatabasePaths._();

  static const databaseDirectory = 'database';
  static const catalog = 'catalog.db';
  static const user = 'user.db';

  static String qualification(String fileName) => fileName;
  static String asset(String fileName) => 'assets/data/$fileName';
}
