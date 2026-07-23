import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppHomeButton extends StatelessWidget {
  const AppHomeButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'ホーム',
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.home_rounded),
      );
}

class AppBarGradient extends StatelessWidget implements PreferredSizeWidget {
  const AppBarGradient({required this.appBar, super.key});
  final AppBar appBar;
  @override
  Size get preferredSize => Size.fromHeight(appBar.preferredSize.height + 5);
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          appBar,
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF123D73), Color(0xFF3B82F6)],
              ),
            ),
          ),
        ],
      );
}

class AppBarBackground extends StatelessWidget {
  const AppBarBackground({super.key});
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF123D73), Color(0xFF174B88)],
          ),
        ),
      );
}
