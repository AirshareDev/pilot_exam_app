import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppHomeButton extends StatelessWidget {
  const AppHomeButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: '戻る',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      );
}

class AppHomeActionButton extends StatelessWidget {
  const AppHomeActionButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: IconButton.filledTonal(
          tooltip: 'ホームへ戻る',
          onPressed: () => context.go('/'),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.home_rounded, size: 21),
        ),
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
