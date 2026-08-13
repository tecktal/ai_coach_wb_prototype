import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/teach/teach_elements.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/coach_script.dart';
import '../../../data/providers/coach_script_provider.dart';

/// The seven-block coaching conversation for one TEACH element.
///
/// Read on a phone, often in a corridor, immediately before walking into a
/// conversation — so the opening question is given visual priority and
/// everything else reads top to bottom in the order it will be used.
class CoachScriptScreen extends StatelessWidget {
  final String recordingId;
  final TeachElement element;

  const CoachScriptScreen({
    super.key,
    required this.recordingId,
    required this.element,
  });

  Future<void> _regenerate(BuildContext context) async {
    final strings = AppStrings.of(context);
    final provider = context.read<CoachScriptProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.coachRegenerate),
        content: Text(strings.coachRegenerateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.coachRegenerate),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final script = await provider.generate(recordingId, element.canonicalKey);
    if (!context.mounted) return;
    if (script == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.coachGenerateFailed)),
      );
    }
  }

  void _copyAll(BuildContext context, CoachScript script) {
    final strings = AppStrings.of(context);
    final buf = StringBuffer()
      ..writeln(strings.byKey(element.labelKey).toUpperCase())
      ..writeln();

    void section(String heading, String? body) {
      if (body == null || body.isEmpty) return;
      buf
        ..writeln(heading.toUpperCase())
        ..writeln(body)
        ..writeln();
    }

    void listSection(String heading, List<String> items) {
      if (items.isEmpty) return;
      buf.writeln(heading.toUpperCase());
      for (final item in items) {
        buf.writeln('• $item');
      }
      buf.writeln();
    }

    listSection(strings.coachBlockEvidence, script.observedEvidence);
    section(strings.coachBlockMeaning, script.whatItMeans);
    section(strings.coachBlockQuestion, script.coachQuestion);
    listSection(strings.coachBlockFollowUps, script.followUpQuestions);
    section(strings.coachBlockModel, script.possibleModel);
    section(strings.coachBlockPractice, script.practice);
    section(strings.coachBlockNextStep, script.nextStep);

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.coachCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final provider = context.watch<CoachScriptProvider>();
    final script = provider.scriptFor(element.canonicalKey);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.byKey(element.labelKey)),
        actions: [
          if (script != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: strings.copy,
              onPressed: () => _copyAll(context, script),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: strings.coachRegenerate,
              onPressed: provider.isGenerating ? null : () => _regenerate(context),
            ),
          ],
        ],
      ),
      body: provider.isGenerating
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(strings.coachGenerating),
                ],
              ),
            )
          : script == null
              ? Center(child: Text(strings.coachGenerateFailed))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    // Domain colour band, matching the analysis screen so the
                    // manual's coding carries through.
                    Container(
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: element.domain.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    _ListBlock(
                      heading: strings.coachBlockEvidence,
                      icon: Icons.hearing_rounded,
                      items: script.observedEvidence,
                      isDark: isDark,
                    ),
                    _TextBlock(
                      heading: strings.coachBlockMeaning,
                      icon: Icons.lightbulb_outline_rounded,
                      body: script.whatItMeans,
                      isDark: isDark,
                    ),

                    // The one line the coordinator says out loud first.
                    _HighlightBlock(
                      heading: strings.coachBlockQuestion,
                      body: script.coachQuestion,
                      accent: element.domain.accent,
                      onSurface: element.domain.onSurface,
                      isDark: isDark,
                    ),

                    _ListBlock(
                      heading: strings.coachBlockFollowUps,
                      icon: Icons.forum_outlined,
                      items: script.followUpQuestions,
                      isDark: isDark,
                    ),
                    _TextBlock(
                      heading: strings.coachBlockModel,
                      icon: Icons.visibility_outlined,
                      body: script.possibleModel,
                      isDark: isDark,
                    ),
                    _TextBlock(
                      heading: strings.coachBlockPractice,
                      icon: Icons.fitness_center_rounded,
                      body: script.practice,
                      isDark: isDark,
                    ),
                    _TextBlock(
                      heading: strings.coachBlockNextStep,
                      icon: Icons.flag_outlined,
                      body: script.nextStep,
                      isDark: isDark,
                    ),
                  ],
                ),
    );
  }
}

class _BlockHeading extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isDark;

  const _BlockHeading({required this.text, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.grey[400] : AppTheme.textSub),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: isDark ? Colors.grey[400] : AppTheme.textSub,
          ),
        ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String heading;
  final IconData icon;
  final String? body;
  final bool isDark;

  const _TextBlock({
    required this.heading,
    required this.icon,
    required this.body,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (body == null || body!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockHeading(text: heading, icon: icon, isDark: isDark),
          const SizedBox(height: 8),
          Text(
            body!,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? Colors.grey[200] : AppTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListBlock extends StatelessWidget {
  final String heading;
  final IconData icon;
  final List<String> items;
  final bool isDark;

  const _ListBlock({
    required this.heading,
    required this.icon,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlockHeading(text: heading, icon: icon, isDark: isDark),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey[400] : AppTheme.textSub,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark ? Colors.grey[200] : AppTheme.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The opening question, set apart because it is the one thing the coordinator
/// reads out loud before the conversation starts.
class _HighlightBlock extends StatelessWidget {
  final String heading;
  final String? body;
  final Color accent;
  final Color onSurface;
  final bool isDark;

  const _HighlightBlock({
    required this.heading,
    required this.body,
    required this.accent,
    required this.onSurface,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (body == null || body!.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? accent.withValues(alpha: 0.14)
            : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over_rounded,
                  size: 16, color: isDark ? Colors.grey[300] : onSurface),
              const SizedBox(width: 8),
              Text(
                heading.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.grey[300] : onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body!,
            style: TextStyle(
              fontSize: 19,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
