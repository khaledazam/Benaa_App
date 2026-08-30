import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HawsuLoadingOverlay extends StatefulWidget {
  final String message;

  const HawsuLoadingOverlay({
    Key? key,
    this.message = 'جاري التوجيه والتحميل حوسو... ⚡',
  }) : super(key: key);

  @override
  State<HawsuLoadingOverlay> createState() => _HawsuLoadingOverlayState();
}

class _HawsuLoadingOverlayState extends State<HawsuLoadingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A86B).withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF004D25), Color(0xFF00A86B), Color(0xFF005C36)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A86B).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 36),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (ctx, child) {
                  return Text(
                    '⚡ حوسو ⚡',
                    style: TextStyle(
                      color: const Color(0xFF00A86B).withOpacity(_pulseAnimation.value),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.borderDark,
                  color: Color(0xFF00A86B),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.message,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'نظام Benaa للمعدات والمواد - بريدة',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom Animated Page Route with Hawsu Loading Screen
class HawsuPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  HawsuPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);

            return Stack(
              children: [
                FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                ),
                // Shows loading screen during the first 300ms of route transition
                if (animation.value < 0.65)
                  Positioned.fill(
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
                        ),
                      ),
                      child: const HawsuLoadingOverlay(),
                    ),
                  ),
              ],
            );
          },
        );
}
