import 'package:flutter/material.dart';

import '../localization.dart';
import '../widgets/http_error_banner.dart';
import 'spare_part_screen.dart';
import 'status_usage_tab.dart';

/// Technician "Parts & Tools" screen — pushed from the tech dashboard tab,
/// with a back button. Three tabs: Spare Parts, Tools, Status Usage.
class TechPartsToolsScreen extends StatelessWidget {
  const TechPartsToolsScreen({super.key, required this.techId});

  final String techId;

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(eng ? 'Parts & Tools' : 'Alat Ganti & Perkakas'),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: const Icon(Icons.build_rounded, size: 20),
                text: eng ? 'Spare Parts' : 'Alat Ganti',
              ),
              Tab(
                icon: const Icon(Icons.handyman_rounded, size: 20),
                text: eng ? 'Tools' : 'Perkakas',
              ),
              Tab(
                icon: const Icon(Icons.receipt_long_rounded, size: 20),
                text: eng ? 'Status Usage' : 'Kegunaan',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const HttpErrorBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  const SparePartScreen(embedded: true),
                  const SparePartScreen(embedded: true, tools: true),
                  StatusUsageTab(techId: techId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}