import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class PilotExamApp extends StatelessWidget {
  const PilotExamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '航空従事者技能証明試験ー学科試験対策',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
