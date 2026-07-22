import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class PilotExamApp extends StatelessWidget {
  const PilotExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'パイロット試験対策',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
