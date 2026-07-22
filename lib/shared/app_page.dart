import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        leading: showBackButton && context.canPop()
            ? IconButton(
                onPressed: context.pop,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(child: body),
    );
  }
}
