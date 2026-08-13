import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/teach/teach_elements.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/analysis.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/coach_script_provider.dart';
import 'coach_script_screen.dart';

/// Lets a coordinator pick which TEACH element to build the conversation around.
///
/// The list comes from [kTeachElements] rather than being hardcoded, so B4 can
/// narrow it to the state's priority skills without rewriting this screen.
class FocalSkillScreen extends StatefulWidget {
  final String recordingId;
  final Analysis analysis;

  /// Elements to offer. Defaults to all nine.
  final List<TeachElement> elements;

  const FocalSkillScreen({
    super.key,
    required this.recordingId,
    required this.analysis,
    this.elements = kTeachElements,
  });

  @override
  State<FocalSkillScreen> createState() => _FocalSkillScreenState();
}

class _FocalSkillScreenState extends State<FocalSkillScreen> {
  @override
  void initState() {
    super.initState();
    // Load after the first frame so the provider can notify freely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CoachScriptProvider>();
      provider.reset();
      provider.loadScripts(widget.recordingId);
    });
  }

  /// The AI score for an element, or null when it wasn't assessed.
  int? _scoreFor(String canonicalKey) {
    switch (canonicalKey) {
      case 'supportive_environment':
        return widget.analysis.supportiveEnvironmentScore;
      case 'positive_expectations':
        return widget.analysis.positiveExpectationsScore;
      case 'lesson_facilitation':
        return widget.analysis.lessonFacilitationScore;
      case 'checks_understanding':
        return widget.analysis.checksUnderstandingScore;
      case 'feedback':
        return widget.analysis.feedbackScore;
      case 'critical_thinking':
        return widget.analysis.criticalThinkingScore;
      case 'autonomy':
        return widget.analysis.autonomyScore;
      case 'perseverance':
        return widget.analysis.perseveranceScore;
      case 'social_collaborative':
        return widget.analysis.socialCollaborativeScore;
      default:
        return null;
    }
  }

  Future<void> _openElement(TeachElement element) async {
    final strings = AppStrings.of(context);
    final provider = context.read<CoachScriptProvider>();

    // Already prepared — open it without regenerating.
    if (provider.hasScriptFor(element.canonicalKey)) {
      _push(element);
      return;
    }

    final script =
        await provider.generate(widget.recordingId, element.canonicalKey);
    if (!mounted) return;

    if (script == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.coachGenerateFailed)),
      );
      return;
    }
    _push(element);
  }

  void _push(TeachElement element) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoachScriptScreen(
          recordingId: widget.recordingId,
          element: element,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final provider = context.watch<CoachScriptProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Skills this deployment prioritises lead the list; everything else follows.
    final priorityKeys = priorityElementKeysFor(
      context.read<AuthProvider>().user?.country,
    );
    final priorityElements = widget.elements
        .where((e) => priorityKeys.contains(e.canonicalKey))
        .toList();
    final otherElements = widget.elements
        .where((e) => !priorityKeys.contains(e.canonicalKey))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(strings.coachChooseFocalSkill)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            strings.coachChooseFocalSkillHelp,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : AppTheme.textSub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Where the programme names priority skills, they lead the list under
          // their own heading; the rest stay reachable below.
          if (priorityElements.isNotEmpty) ...[
            _groupHeading(strings.statePriorities, isDark),
            ...priorityElements.map(_buildElementTile),
            const SizedBox(height: 20),
            _groupHeading(strings.allTeachElements, isDark),
          ],
          ...otherElements.map(_buildElementTile),
          if (provider.isGenerating) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                strings.coachGenerating,
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : AppTheme.textSub),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _groupHeading(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: isDark ? Colors.grey[400] : AppTheme.textSub,
          ),
        ),
      );

  Widget _buildElementTile(TeachElement element) {
    final strings = AppStrings.of(context);
    final provider = context.watch<CoachScriptProvider>();
    final prepared = provider.hasScriptFor(element.canonicalKey);
    final busy = provider.generatingElementKey == element.canonicalKey;
    final score = _scoreFor(element.canonicalKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: element.domain.accent.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: element.domain.tint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(element.icon, color: element.domain.onSurface, size: 20),
        ),
        title: Text(
          strings.byKey(element.labelKey),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            strings.byKey(element.domain.labelKey),
            // Score is context for choosing, not a judgement to lead with.
            if (score != null) '${strings.rating}: $score/5',
            if (prepared) '✓ ${strings.coachPrepared}',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: provider.isGenerating ? null : () => _openElement(element),
      ),
    );
  }
}
