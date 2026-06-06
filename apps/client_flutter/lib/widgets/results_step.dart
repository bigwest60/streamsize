import 'package:flutter/material.dart';
import 'package:streamsize_core/streamsize_core.dart';

class ResultsStep extends StatelessWidget {
  const ResultsStep({
    required this.recommendation,
    required this.scenario,
    required this.isSpeedTesting,
    required this.onRunSpeedTest,
    required this.onShareText,
    required this.onExportPdf,
    this.measuredDownloadMbps,
    this.measuredUploadMbps,
  });

  final PlanRecommendation recommendation;
  final HouseholdScenario scenario;
  final bool isSpeedTesting;
  final double? measuredDownloadMbps;
  final double? measuredUploadMbps;
  final VoidCallback onRunSpeedTest;
  final VoidCallback onShareText;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shouldSkipGigabit = recommendation.downloadMbps < 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Your right-sized plan: ${recommendation.downloadMbps} Mbps download, ${recommendation.uploadMbps} Mbps upload. ${recommendation.planLabel}.',
          container: true,
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Text('Your right-sized plan', style: theme.textTheme.headlineSmall),
                ),
                _RecommendationConfidenceBadge(confidence: recommendation.confidence),
              ],
            ),
          ),
        ),
        if (recommendation.confidence == ConfidenceScore.low) ...[
          const SizedBox(height: 8),
          Text(
            'No devices detected — the estimate is based on your usage answers only. Go back and add devices manually for a more accurate result.',
            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFC26A5A), height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Based on the devices we saw and the busiest moments you described, here is the plan we would recommend.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2D1E2F), Color(0xFF4A3150)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  shouldSkipGigabit ? 'You probably do not need gigabit' : 'Heavy-usage household',
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${recommendation.downloadMbps}',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Mbps',
                      style: theme.textTheme.headlineSmall?.copyWith(color: const Color(0xFFF0E0F8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Recommended plan: ${recommendation.planLabel}',
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                shouldSkipGigabit
                    ? 'This should comfortably cover ${scenario.simultaneous4kStreams} 4K streams, ${scenario.simultaneousVideoCalls} live calls, and everyday browsing without paying for a premium tier you are unlikely to feel.'
                    : 'Your peak-time habits suggest a faster tier is justified so the busiest moments still feel smooth.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFF0E0F8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DarkStatPill(label: 'Upload ${recommendation.uploadMbps} Mbps'),
                  Semantics(
                    label: 'Confidence: ${recommendation.confidence.name}',
                    container: true,
                    child: ExcludeSemantics(
                      child: _DarkStatPill(label: 'Confidence ${recommendation.confidence.name}'),
                    ),
                  ),
                  _DarkStatPill(label: '${scenario.devices.length} devices considered'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Speed test section
        SpotlightCard(
          title: 'Compare with your actual speed',
          subtitle: 'Optional — run a quick test to see how your current plan compares to our recommendation.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (measuredDownloadMbps != null || measuredUploadMbps != null) ...[
                _SpeedComparisonRow(
                  label: 'Download',
                  recommended: recommendation.downloadMbps.toDouble(),
                  measured: measuredDownloadMbps,
                ),
                const SizedBox(height: 8),
                _SpeedComparisonRow(
                  label: 'Upload',
                  recommended: recommendation.uploadMbps.toDouble(),
                  measured: measuredUploadMbps,
                ),
                const SizedBox(height: 12),
              ],
              TextButton.icon(
                onPressed: isSpeedTesting ? null : onRunSpeedTest,
                icon: isSpeedTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.speed_rounded, size: 18),
                label: Text(isSpeedTesting ? 'Testing...' : 'Test actual speed'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Export/share buttons
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: onShareText,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Share'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onExportPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Export PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _ResultNarrativeCard(
                title: 'Why this plan should feel right',
                icon: Icons.favorite_border_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: recommendation.reasons
                      .map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.check_circle, size: 18, color: Color(0xFFE07A5F)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(reason, style: theme.textTheme.bodyLarge)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ResultNarrativeCard(
                title: 'What you are not paying for',
                icon: Icons.savings_outlined,
                child: Text(
                  shouldSkipGigabit
                      ? 'Good news: this result suggests your home probably does not need a top-tier gigabit plan unless your usage grows or you want extra upload headroom.'
                      : 'A faster tier looks justified here, but the recommendation is still sized to your real usage rather than the biggest plan on the price sheet.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecommendationConfidenceBadge extends StatelessWidget {
  const _RecommendationConfidenceBadge({required this.confidence});

  final ConfidenceScore confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      ConfidenceScore.high => ('High confidence', const Color(0xFF3FA56A)),
      ConfidenceScore.medium => ('Good estimate', const Color(0xFF4A90D9)),
      ConfidenceScore.low => ('Rough estimate', const Color(0xFFC26A5A)),
    };

    return Semantics(
      label: 'Recommendation confidence: $label',
      container: true,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _SpeedComparisonRow extends StatelessWidget {
  const _SpeedComparisonRow({
    required this.label,
    required this.recommended,
    this.measured,
  });

  final String label;
  final double recommended;
  final double? measured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (measured == null) {
      return Row(
        children: [
          Expanded(child: Text('$label:', style: theme.textTheme.bodyMedium)),
          Text('–', style: theme.textTheme.bodyMedium),
        ],
      );
    }
    final ratio = measured! / recommended;
    final color = ratio >= 0.8
        ? const Color(0xFF3FA56A)
        : ratio >= 0.5
            ? const Color(0xFFE09A3E)
            : const Color(0xFFC26A5A);
    final measuredStr = measured! >= 100
        ? '${measured!.round()} Mbps'
        : '${measured!.toStringAsFixed(1)} Mbps';

    return Row(
      children: [
        Expanded(child: Text('$label:', style: theme.textTheme.bodyMedium)),
        Text(
          '$measuredStr vs ${recommended.round()} Mbps recommended',
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class SpotlightCard extends StatelessWidget {
  const SpotlightCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ResultNarrativeCard extends StatelessWidget {
  const _ResultNarrativeCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE07A5F)),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DarkStatPill extends StatelessWidget {
  const _DarkStatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}
