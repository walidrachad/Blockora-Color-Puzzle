import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cartoon_ui.dart';
import '../application/game_cubit.dart';
import 'cartoon_gameplay_screen.dart';

class CartoonGameShell extends StatelessWidget {
  const CartoonGameShell({
    super.key,
    required this.cubit,
    this.onExit,
  });

  final GameCubit cubit;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: cartoonBackground(),
      child: Stack(
        children: [
          const Positioned(
            left: -20,
            top: 90,
            child: _CornerToy(color: Color(0xff54c8ed), angle: -.14),
          ),
          const Positioned(
            right: -18,
            top: 180,
            child: _CornerToy(color: Color(0xff9bd528), angle: .14),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: CartoonColors.paper,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: CartoonColors.outline,
                    width: 5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 10,
                      offset: Offset(7, 9),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: BlocProvider.value(
                  value: cubit,
                  child: CartoonGameplayScreen(onExit: onExit),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CornerToy extends StatelessWidget {
  const _CornerToy({required this.color, required this.angle});

  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .4), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 6,
            offset: Offset(4, 6),
          ),
        ],
      ),
    ),
  );
}
