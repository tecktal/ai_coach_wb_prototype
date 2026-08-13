import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/teach/teach_elements.dart';
import '../../../../data/models/analysis.dart';
import '../../../../core/l10n/app_strings.dart';

/// Called when a teacher taps an element.
/// [canonicalKey] is the stable identity (e.g. 'supportive_environment') used
/// for lookups; [label] is the already-translated display name.
typedef ElementTapCallback = void Function(
  String canonicalKey,
  String label,
  ElementAnalysis? element,
  TeachDomain domain,
);

class TeachGridWidget extends StatelessWidget {
  final Analysis analysis;
  final ElementTapCallback onElementTap;

  const TeachGridWidget({
    super.key,
    required this.analysis,
    required this.onElementTap,
  });

  /// LEGACY COMPATIBILITY SHIM — do not treat as current scoring logic.
  ///
  /// Analyses created before the Phase 0 scoring fix stored N/A as a score of 1
  /// (the backend clamped 0 to 1 to satisfy a DB constraint, and three elements
  /// were never parsed at all and so defaulted to 1 with empty behaviors). This
  /// heuristic maps those rows back to N/A so they don't read as a false
  /// "Needs Focus".
  ///
  /// Analyses created after the fix store N/A as null and never need this: a
  /// genuine score of 1 now arrives with real behaviors, so the heuristic
  /// correctly does not fire on it.
  ///
  /// Safe to delete once pre-fix analyses are gone or backfilled.
  int _getEffectiveScore(ElementAnalysis? element) {
    if (element == null) return 0;

    if (element.score == 1) {
      // If we have no behaviors, or all behaviors are N/A, treat as N/A (0)
      if (element.behaviors.isEmpty) {
        return 0;
      }

      bool hasActualRating = false;
      for (var b in element.behaviors.values) {
        if (b.rating.toUpperCase() != 'N/A' && b.rating != '0') {
          hasActualRating = true;
          break;
        }
      }

      if (!hasActualRating) return 0;
    }

    return element.score;
  }

  /// The parsed AI analysis for one element, by canonical key.
  ElementAnalysis? _elementData(String canonicalKey) {
    switch (canonicalKey) {
      case 'supportive_environment':
        return analysis.supportiveEnvironment;
      case 'positive_expectations':
        return analysis.positiveExpectations;
      case 'lesson_facilitation':
        return analysis.lessonFacilitation;
      case 'checks_understanding':
        return analysis.checksUnderstanding;
      case 'feedback':
        return analysis.feedback;
      case 'critical_thinking':
        return analysis.criticalThinking;
      case 'autonomy':
        return analysis.autonomy;
      case 'perseverance':
        return analysis.perseverance;
      case 'social_collaborative':
        return analysis.socialCollaborative;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final domain in TeachDomain.values) ...[
          _buildCollapsibleDomain(
            context,
            domain,
            strings.byKey(domain.labelKey),
            kTeachElementsByDomain[domain]!
                .map((element) => _createData(context, element))
                .toList(),
          ),
          if (domain != TeachDomain.values.last) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Map<String, dynamic> _createData(BuildContext context, TeachElement element) {
    final data = _elementData(element.canonicalKey);
    return {
      'canonicalKey': element.canonicalKey,
      'label': AppStrings.of(context).byKey(element.labelKey),
      'element': data,
      'score': _getEffectiveScore(data),
      'icon': element.icon,
      'domain': element.domain,
    };
  }

  Widget _buildCollapsibleDomain(
    BuildContext context,
    TeachDomain domain,
    String title,
    List<Map<String, dynamic>> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // The manual's domain colour, carried on the card edge.
        border: Border.all(color: domain.accent.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              // Domain colour swatch — the manual's coding, made explicit.
              Container(
                width: 6,
                height: 34,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: domain.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            // Contrast-safe shade — never `domain.accent`, which
                            // fails AA on white for the yellow domain.
                            color: domain.onSurface,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.of(context).tapToViewElements(items.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
              // No score labels per World Bank feedback — domain title only
            ],
          ),
          children: [
            const SizedBox(height: 16),

            // Pros Section
            if (items.any((i) => (i['score'] as int) >= 3)) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(AppStrings.of(context).pros, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 12)),
                  ],
                ),
              ),
              ...items.where((i) => (i['score'] as int) >= 3).map((item) => _buildTeachListTile(context, item)),
              const SizedBox(height: 16),
            ],

            // Cons Section
            if (items.any((i) => (i['score'] as int) < 3 && (i['score'] as int) > 0)) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(AppStrings.of(context).cons, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 12)),
                  ],
                ),
              ),
              ...items.where((i) => (i['score'] as int) < 3 && (i['score'] as int) > 0).map((item) => _buildTeachListTile(context, item)),
            ],

            // N/A Section (Optional, maybe hide or show at bottom)
            if (items.any((i) => (i['score'] as int) == 0)) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline, color: Colors.grey.shade400, size: 16),
                    const SizedBox(width: 8),
                    Text(AppStrings.of(context).notObservedSection, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              ...items.where((i) => (i['score'] as int) == 0).map((item) => _buildTeachListTile(context, item)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeachListTile(BuildContext context, Map<String, dynamic> item) {
    final domain = item['domain'] as TeachDomain;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: domain.tint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item['icon'] as IconData, color: domain.onSurface, size: 18),
        ),
        title: Text(
          item['label'] as String,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
              ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
        onTap: () {
          if (item['element'] != null) {
            onElementTap(
              item['canonicalKey'] as String,
              item['label'] as String,
              item['element'] as ElementAnalysis?,
              domain,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.of(context).noDetailedAnalysis)),
            );
          }
        },
      ),
    );
  }
}
