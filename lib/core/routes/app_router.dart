import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dukaan_mate/features/dashboard/dashboard_screen.dart';
import 'package:dukaan_mate/features/billing/bills_screen.dart';
import 'package:dukaan_mate/features/products/products_screen.dart';
import 'package:dukaan_mate/features/settings/settings_screen.dart';
import 'package:dukaan_mate/features/billing/new_bill_screen.dart';
import 'package:dukaan_mate/features/calculator/weight_calculator_screen.dart';
import 'package:dukaan_mate/features/calculator/smart_calculator_screen.dart';
import 'package:dukaan_mate/features/customers/customers_screen.dart';
import 'package:dukaan_mate/features/reports/reports_screen.dart';
import 'package:dukaan_mate/features/settings/qr_codes_screen.dart';
import 'package:dukaan_mate/features/customers/customer_details_screen.dart';
import 'main_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      navigatorContainerBuilder: (context, navigationShell, children) {
        return AnimatedBranchContainer(
          currentIndex: navigationShell.currentIndex,
          children: children,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bills',
              builder: (context, state) => const BillsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/products',
              builder: (context, state) => const ProductsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/new_bill',
      builder: (context, state) => const NewBillScreen(),
    ),
    GoRoute(
      path: '/weight_calculator',
      builder: (context, state) => const WeightCalculatorScreen(),
    ),
    GoRoute(
      path: '/smart_calculator',
      builder: (context, state) => const SmartCalculatorScreen(),
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomersScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return CustomerDetailsScreen(customerId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/qrcodes',
      builder: (context, state) => const QRCodesScreen(),
    ),
  ],
);

class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() => _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0.05, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: IndexedStack(
          index: widget.currentIndex,
          children: widget.children,
        ),
      ),
    );
  }
}
