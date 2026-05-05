import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';
import '../data/models/value_model.dart';
import '../data/models/values_plan_model.dart';
import '../features/dashboard/screens/budget_plan_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/onboarding/screens/completion_screen.dart';
import '../features/onboarding/screens/plan_screen.dart';
import '../features/onboarding/screens/prioritize_screen.dart';
import '../features/onboarding/screens/values_screen.dart';
import '../features/onboarding/screens/welcome_screen.dart';
import '../features/reflect/screens/journal_entry_screen.dart';
import '../features/analytics/screens/analytics_screen.dart';
import '../features/reflect/screens/money_story_screen.dart';
import '../features/reflect/screens/reflect_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/recurring/screens/add_recurring_screen.dart';
import '../features/recurring/screens/recurring_history_screen.dart';
import '../features/recurring/screens/recurring_screen.dart';
import '../features/transactions/screens/add_session_screen.dart';
import '../features/transactions/screens/transaction_detail_screen.dart';
import '../features/transactions/screens/transactions_screen.dart';
import '../providers/settings_provider.dart';

// ---------------------------------------------------------------------------
// Slide page transition helper
// ---------------------------------------------------------------------------

CustomTransitionPage<void> _slidePage(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Router notifier
// ---------------------------------------------------------------------------

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<bool>>(
      onboardingCompleteProvider,
      (_, __) => notifyListeners(),
    );
    Future.delayed(_minSplashDuration, () {
      _minSplashElapsed = true;
      notifyListeners();
    });
  }

  static const _minSplashDuration = Duration(milliseconds: 2400);

  final Ref _ref;
  bool _minSplashElapsed = false;

  bool get isOnboardingComplete =>
      _ref.read(onboardingCompleteProvider).valueOrNull ?? false;

  bool get isLoading =>
      _ref.read(onboardingCompleteProvider).isLoading || !_minSplashElapsed;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isSplash = state.fullPath == '/splash';

      if (notifier.isLoading) return isSplash ? null : '/splash';

      final onboardingComplete = notifier.isOnboardingComplete;
      final isOnboarding = state.fullPath?.startsWith('/onboarding') ?? false;

      if (isSplash) {
        return onboardingComplete ? '/' : '/onboarding';
      }
      if (!onboardingComplete && !isOnboarding) return '/onboarding';
      if (onboardingComplete && isOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      // ── Onboarding ────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/onboarding/values',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const ValuesScreen()),
      ),
      GoRoute(
        path: '/onboarding/prioritize',
        pageBuilder: (_, state) {
          final values = state.extra as List<ValueModel>? ?? [];
          return _slidePage(
            state.pageKey,
            PrioritizeScreen(selectedValues: values),
          );
        },
      ),
      GoRoute(
        path: '/onboarding/plan',
        pageBuilder: (_, state) {
          final values = state.extra as List<ValueModel>? ?? [];
          return _slidePage(state.pageKey, PlanScreen(values: values));
        },
      ),
      GoRoute(
        path: '/onboarding/complete',
        pageBuilder: (_, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            state.pageKey,
            CompletionScreen(
              values: (data['values'] as List?)?.cast<ValueModel>() ?? [],
              plans: (data['plans'] as List?)?.cast<ValuesPlanModel>() ?? [],
              income: (data['income'] as int?) ?? 0,
            ),
          );
        },
      ),

      // ── Add session (full-screen, no bottom nav) ──────────────────
      GoRoute(
        path: '/add-session',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const AddSessionScreen()),
      ),

      // ── Edit session (full-screen, no bottom nav) ─────────────────
      GoRoute(
        path: '/edit-session/:id',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          AddSessionScreen(editTransactionId: state.pathParameters['id']!),
        ),
      ),

      // ── Transaction detail (full-screen, no bottom nav) ───────────
      GoRoute(
        path: '/transactions/:id',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          TransactionDetailScreen(transactionId: state.pathParameters['id']!),
        ),
      ),

      // ── Journal entry (full-screen, no bottom nav) ────────────────
      GoRoute(
        path: '/reflect/new',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const JournalEntryScreen()),
      ),
      GoRoute(
        path: '/reflect/money-story',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const MoneyStoryScreen()),
      ),
      GoRoute(
        path: '/reflect/money-story/:id',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          MoneyStoryScreen(entryId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/reflect/:id',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          JournalEntryScreen(entryId: state.pathParameters['id']),
        ),
      ),

      // ── Budget plan (full-screen, accessible from Dashboard) ──────
      GoRoute(
        path: '/budget-plan',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const BudgetPlanScreen()),
      ),

      // ── Analytics (full-screen, accessible from Dashboard) ────────
      GoRoute(
        path: '/analytics',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const AnalyticsScreen()),
      ),

      // ── Recurring expenses ────────────────────────────────────────
      GoRoute(
        path: '/recurring',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const RecurringScreen()),
      ),
      GoRoute(
        path: '/recurring/add',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const AddRecurringScreen()),
      ),
      GoRoute(
        path: '/recurring/history',
        pageBuilder: (_, state) =>
            _slidePage(state.pageKey, const RecurringHistoryScreen()),
      ),
      GoRoute(
        path: '/recurring/edit',
        pageBuilder: (_, state) => _slidePage(
          state.pageKey,
          AddRecurringScreen(editExpense: state.extra as dynamic),
        ),
      ),

      // ── Main shell with bottom nav ────────────────────────────────
      ShellRoute(
        builder: (_, state, child) =>
            _MainShell(location: state.fullPath ?? '/', child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/transactions',
            builder: (_, __) => const TransactionsScreen(),
          ),
          GoRoute(path: '/reflect', builder: (_, __) => const ReflectScreen()),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Main shell — BottomNavigationBar with a centre FAB.
// Tabs: Today | History | [FAB] | Reflect | Settings
// ---------------------------------------------------------------------------

class _MainShell extends StatelessWidget {
  const _MainShell({required this.child, required this.location});

  final Widget child;
  final String location;

  int _selectedIndex(String loc) {
    if (loc.startsWith('/transactions')) return 1;
    if (loc == '/reflect') return 2;
    if (loc.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _selectedIndex(location);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-session'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Today',
                selected: index == 0,
                onTap: () => context.go('/'),
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'History',
                selected: index == 1,
                onTap: () => context.go('/transactions'),
              ),
              const SizedBox(width: 48),
              _NavItem(
                icon: Icons.lightbulb_outline,
                activeIcon: Icons.lightbulb,
                label: 'Reflect',
                selected: index == 2,
                onTap: () => context.go('/reflect'),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                selected: index == 3,
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
