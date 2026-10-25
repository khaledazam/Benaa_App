import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'dashboard_screen.dart';
import 'local_stock_screen.dart';
import 'operations_hub_screen.dart';
import 'more_hub_screen.dart';

/// Predictable Enterprise 4-Tab Bottom Navigation Shell for Benaa
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({
    Key? key,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    DashboardScreen(),
    LocalStockScreen(),
    OperationsHubScreen(),
    MoreHubScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);
    final activeColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final indicatorBg = isDark
        ? AppColors.primary.withOpacity(0.35)
        : const Color(0xFFDBEAFE);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: navBg,
            indicatorColor: indicatorBg,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              final isSelected = states.contains(MaterialState.selected);
              return AppTypography.smallLabel(
                color: isSelected
                    ? activeColor
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              );
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              final isSelected = states.contains(MaterialState.selected);
              return IconThemeData(
                size: 24,
                color: isSelected
                    ? activeColor
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'المخزون',
              ),
              NavigationDestination(
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(Icons.swap_horiz_rounded),
                label: 'العمليات',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_rounded),
                selectedIcon: Icon(Icons.menu_open_rounded),
                label: 'المزيد',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
