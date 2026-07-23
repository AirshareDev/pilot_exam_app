import 'package:flutter/material.dart';

import '../design/app_app_bar.dart';

class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,
    required this.body,
    this.showBackButton = true,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final Widget body;
  final bool showBackButton;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarGradient(
        appBar: AppBar(
          leading: showBackButton ? const AppHomeButton() : null,
          automaticallyImplyLeading: false,
          title: Text(title),
          actions: actions,
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}
