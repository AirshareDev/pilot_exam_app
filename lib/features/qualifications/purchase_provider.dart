import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/user_database.dart';

final purchasedQualificationCodesProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(userDatabaseProvider).loadPurchasedQualificationCodes();
});
