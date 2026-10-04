import 'package:flutter/material.dart';

import 'theme.dart';

class CartoonColors {
  static const backgroundTop = Color(0xffc79b9a);
  static const backgroundBottom = Color(0xff8f666c);
  static const paper = Color(0xfffff5e8);
  static const paperWarm = Color(0xffffe9c9);
  static const outline = Color(0xff78658f);
  static const outlineDark = Color(0xff514266);
  static const text = Color(0xff74452f);
  static const textSoft = Color(0xff9a705a);
  static const ribbon = Color(0xffef3f8f);
  static const ribbonDark = Color(0xffc92d75);
  static const green = Color(0xff9bd51f);
  static const greenDark = Color(0xff68a40e);
  static const blue = Color(0xff39bdea);
  static const blueDark = Color(0xff178ab8);
  static const yellow = Color(0xffffd53f);
  static const orange = Color(0xffff8c2e);
}

BoxDecoration cartoonBackground() => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [CartoonColors.backgroundTop, CartoonColors.backgroundBottom],
  ),
);

class CartoonPanel extends StatelessWidget {
  const CartoonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 30, 20, 20),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: CartoonColors.paper,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: CartoonColors.outline, width: 6),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 10,
          offset: Offset(8, 10),
        ),
      ],
    ),
    child: child,
  );
}

class CartoonRibbon extends StatelessWidget {
  const CartoonRibbon({
    super.key,
    required this.text,
    this.width = 240,
    this.icon,
  });

  final String text;
  final double width;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 72,
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          bottom: 4,
          child: Transform.rotate(
            angle: -.10,
            child: Container(
              width: 52,
              height: 32,
              decoration: const BoxDecoration(
                color: CartoonColors.ribbonDark,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 4,
          child: Transform.rotate(
            angle: .10,
            child: Container(
              width: 52,
              height: 32,
              decoration: const BoxDecoration(
                color: CartoonColors.ribbonDark,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffff5aaa), CartoonColors.ribbon],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffff8cc2), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 5,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .6,
                    shadows: [
                      Shadow(
                        color: Color(0x55000000),
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GlossyGameButton extends StatefulWidget {
  const GlossyGameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.green = true,
    this.height = 58,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool green;
  final double height;

  @override
  State<GlossyGameButton> createState() => _GlossyGameButtonState();
}

class _GlossyGameButtonState extends State<GlossyGameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final top = widget.green ? const Color(0xffb8e62d) : const Color(0xff52d6f7);
    final bottom = widget.green ? CartoonColors.greenDark : CartoonColors.blueDark;

    return AnimatedScale(
      scale: _pressed ? .95 : 1,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [top, bottom],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .65), width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 16,
                  right: 16,
                  top: 5,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoundGameButton extends StatefulWidget {
  const RoundGameButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.showShadow = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool showShadow;

  @override
  State<RoundGameButton> createState() => _RoundGameButtonState();
}

class _RoundGameButtonState extends State<RoundGameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedScale(
      scale: _pressed ? .9 : 1,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffb7e72c), CartoonColors.greenDark],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .65), width: 2),
            boxShadow: widget.showShadow
                ? const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 6,
                      offset: Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Icon(widget.icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

class CartoonScoreCard extends StatelessWidget {
  const CartoonScoreCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: CartoonColors.paperWarm,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xffe5b77f), width: 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: PrismColors.orange, size: 20),
          const SizedBox(width: 7),
        ],
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: CartoonColors.textSoft,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: CartoonColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
