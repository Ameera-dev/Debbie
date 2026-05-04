import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/tide.dart';
import '../widgets/performance_history_card.dart';
import 'dashboard_screen.dart';

class BudgetPlanScreen extends StatelessWidget {
  const BudgetPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TidePageBackground(
        child: CustomScrollView(
          slivers: [
            TideScrollHeader(
              compactTitle: 'Budget Plan',
              eyebrow: 'WEEKLY',
              expandedTitle: Text(
                'Budget Plan',
                style: GoogleFonts.lora(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle:
                  'Plan your daily spending and actualize each day as it comes.',
              showBackButton: true,
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              sliver: SliverToBoxAdapter(
                child: WeeklyBudgetPlanCard(),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverToBoxAdapter(
                child: PerformanceHistoryCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
