import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/analysis_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/models/analysis.dart';
import '../../../data/models/recording.dart';
import '../../../data/services/api_service.dart';
import '../analysis/analysis_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/offline_banner.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/roles/role_copy.dart';
import 'widgets/lesson_card.dart';
import 'local_draft_detail_screen.dart';

enum SortOption {
  alphabeticalAZ,
  alphabeticalZA,
  dateNewest,
  dateOldest,
}

/// Filter for the analysis status tabs in My Lessons.
enum AnalysisFilter {
  all,
  analyzed,
  notAnalyzed,
}

class RecordingsListScreen extends StatefulWidget {
  const RecordingsListScreen({super.key});

  @override
  State<RecordingsListScreen> createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen>
    with WidgetsBindingObserver {
  SortOption _currentSort = SortOption.dateNewest;
  String _searchQuery = '';
  String? _selectedCategory;
  AnalysisFilter _analysisFilter = AnalysisFilter.all;

  @override
  void initState() {
    super.initState();
    // Wire up the polling callback ONCE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RecordingProvider>();
      final userId = context.read<AuthProvider>().user?.id;
      provider.onStatusChanged = _onRecordingStatusChanged;
      provider.startPollingIfNeeded();
      provider.loadRecordings(silent: true, userId: userId);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        final userId = context.read<AuthProvider>().user?.id;
        context.read<RecordingProvider>().loadRecordings(silent: true, userId: userId);
        context.read<AnalysisProvider>().loadAnalyses();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Remove our callback so it doesn't fire after we're gone
    final provider = context.read<RecordingProvider>();
    if (provider.onStatusChanged == _onRecordingStatusChanged) {
      provider.onStatusChanged = null;
    }
    super.dispose();
  }

  void _onRecordingStatusChanged(Recording recording, String previousStatus) {
    if (!mounted) return;

    if (recording.isCompleted) {
      // Refresh analyses so the score shows up
      context.read<AnalysisProvider>().loadAnalyses();
      AppToast.show(
        context,
        message: '"${recording.title ?? AppStrings.of(context).untitledLesson}" ${AppStrings.of(context).analysisReady}',
        type: ToastType.success,
        duration: const Duration(seconds: 5),
      );
    } else if (recording.isFailed || recording.isInsufficientAudio) {
      AppToast.show(
        context,
        message:
            '${AppStrings.of(context).analysisCouldNotComplete} "${recording.title ?? AppStrings.of(context).untitledLesson}". ${AppStrings.of(context).tapToSeeDetails}',
        type: ToastType.error,
        duration: const Duration(seconds: 6),
      );
    }
  }

  List<Recording> _sortRecordings(
      List<Recording> recordings, Map<String, Analysis> analysisMap) {
    // 1. Filter by Search
    var filtered = recordings.where((r) {
      final title = r.title?.toLowerCase() ?? '';
      final subject = r.subject?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || subject.contains(query);
    }).toList();

    // 2. Filter by Category (subject)
    if (_selectedCategory != null) {
      filtered = filtered
          .where((r) => (r.subject?.toLowerCase() ?? '')
              .contains(_selectedCategory!.toLowerCase()))
          .toList();
    }

    // 3. Filter by analysis status
    if (_analysisFilter != AnalysisFilter.all) {
      filtered = filtered.where((r) {
        final hasAnalysis =
            analysisMap.containsKey(r.id) && r.isCompleted && !r.isLocalDraft;
        return _analysisFilter == AnalysisFilter.analyzed
            ? hasAnalysis
            : !hasAnalysis;
      }).toList();
    }

    // 4. Sort — local drafts always stay at the top regardless of sort
    final drafts = filtered.where((r) => r.isLocalDraft).toList();
    final rest = filtered.where((r) => !r.isLocalDraft).toList();

    rest.sort((a, b) {
      switch (_currentSort) {
        case SortOption.alphabeticalAZ:
          return (a.title ?? '').compareTo(b.title ?? '');
        case SortOption.alphabeticalZA:
          return (b.title ?? '').compareTo(a.title ?? '');
        case SortOption.dateNewest:
          return b.createdAt.compareTo(a.createdAt);
        case SortOption.dateOldest:
          return a.createdAt.compareTo(b.createdAt);
      }
    });

    return [...drafts, ...rest];
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 16),
                child: Text(
                  AppStrings.of(context).sortBy,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              _buildSortOption(AppStrings.of(context).sortAlphabeticalAZ, Icons.sort_by_alpha,
                  SortOption.alphabeticalAZ),
              _buildSortOption(AppStrings.of(context).sortAlphabeticalZA, Icons.sort_by_alpha,
                  SortOption.alphabeticalZA),
              _buildSortOption(AppStrings.of(context).sortDateNewest, Icons.calendar_today,
                  SortOption.dateNewest),
              _buildSortOption(AppStrings.of(context).sortDateOldest, Icons.calendar_today,
                  SortOption.dateOldest),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, IconData icon, SortOption option) {
    final isSelected = _currentSort == option;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Theme.of(context).primaryColor
            : (isDark ? Colors.grey[400] : Colors.grey),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Theme.of(context).primaryColor
              : (isDark ? Colors.white : AppTheme.textMain),
        ),
      ),
      trailing:
          isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
      onTap: () {
        setState(() => _currentSort = option);
        Navigator.pop(context);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordingProvider = context.watch<RecordingProvider>();
    final analysisProvider = context.watch<AnalysisProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Map<String, Analysis> analysisMap = {
      for (var a in analysisProvider.analyses) a.recordingId: a
    };

    final sortedRecordings =
        _sortRecordings(recordingProvider.recordings, analysisMap);

    // Count for tab badges
    final totalAnalyzed = recordingProvider.recordings
        .where((r) =>
            !r.isLocalDraft &&
            r.isCompleted &&
            analysisMap.containsKey(r.id))
        .length;
    final totalNotAnalyzed =
        recordingProvider.recordings.length - totalAnalyzed;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          RoleCopy.of(context).lessonsTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textMain,
              ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Subtle pulsing dot when polling is active
          if (recordingProvider.hasProcessingRecordings)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Analysis in progress…',
                child: _PollingDot(),
              ),
            ),
          // Uploading drafts indicator
          if (recordingProvider.isUploadingDrafts)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Tooltip(
                message: 'Uploading drafts…',
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Offline banner
            const OfflineBanner(),

            // ── Search & Category Filter ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? Colors.transparent
                              : Colors.grey.shade200),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textMain),
                      decoration: InputDecoration(
                        hintText: AppStrings.of(context).searchLessons,
                        hintStyle: TextStyle(
                            color: isDark
                                ? Colors.grey[500]
                                : Colors.grey.shade400),
                        prefixIcon: Icon(Icons.search,
                            color: isDark
                                ? Colors.grey[500]
                                : Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filter + Sort
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey.shade200),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedCategory,
                            isDense: true,
                            dropdownColor: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            icon: Icon(Icons.keyboard_arrow_down,
                                size: 18,
                                color: Theme.of(context).primaryColor),
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(AppStrings.of(context).all),
                              ),
                              ...[
                                AppStrings.of(context).subjectMath,
                                AppStrings.of(context).subjectScience,
                                AppStrings.of(context).subjectEnglish,
                                AppStrings.of(context).subjectHistory,
                                AppStrings.of(context).subjectArt
                              ].map((String value) {
                                return DropdownMenuItem<String?>(
                                    value: value, child: Text(value));
                              })
                            ],
                            onChanged: (val) {
                              setState(() => _selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showSortOptions,
                        icon: const Icon(Icons.sort_rounded, size: 18),
                        label: Text(AppStrings.of(context).sort),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Analysis Filter Tabs ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildFilterTab(
                      label: AppStrings.of(context).all,
                      count: recordingProvider.recordings.length,
                      filter: AnalysisFilter.all,
                      isDark: isDark,
                    ),
                    _buildFilterTab(
                      label: AppStrings.of(context).analyzed,
                      count: totalAnalyzed,
                      filter: AnalysisFilter.analyzed,
                      isDark: isDark,
                    ),
                    _buildFilterTab(
                      label: AppStrings.of(context).notAnalyzed,
                      count: totalNotAnalyzed,
                      filter: AnalysisFilter.notAnalyzed,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Lessons List ──────────────────────────────────────────────
            Expanded(
              child: recordingProvider.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: Theme.of(context).primaryColor))
                  : sortedRecordings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic_none_rounded,
                                  size: 80,
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey.shade200),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.of(context).noLessonsFound,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey.shade400,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: Theme.of(context).primaryColor,
                          onRefresh: () async {
                            await Future.wait([
                              context
                                  .read<RecordingProvider>()
                                  .loadRecordings(),
                              context.read<AnalysisProvider>().loadAnalyses(),
                            ]);
                          },
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: sortedRecordings.length,
                            itemBuilder: (context, index) {
                              final recording = sortedRecordings[index];
                              final analysis = analysisMap[recording.id];

                              return LessonCard(
                                recording: recording,
                                score: analysis?.overallScore,
                                isUploading: recordingProvider.isDraftUploading(recording.id),
                                onTap: () => _navigateToAnalysis(
                                    context, recording, analysis),
                                onLongPress: () => _deleteRecording(
                                    context, recordingProvider, recording.id),
                                onDelete: () => _deleteRecording(
                                    context, recordingProvider, recording.id),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required int count,
    required AnalysisFilter filter,
    required bool isDark,
  }) {
    final isSelected = _analysisFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _analysisFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDark ? Colors.grey[500] : Colors.grey.shade500),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDark ? Colors.grey[400] : Colors.grey.shade500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAnalysis(
    BuildContext context,
    Recording recording,
    Analysis? analysis,
  ) async {
    // Local drafts → open the draft detail screen
    if (recording.isLocalDraft) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocalDraftDetailScreen(recording: recording),
        ),
      );
      return;
    }

    if (analysis != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AnalysisScreen(analysisId: analysis.id)),
      );
      return;
    }

    if (recording.isCompleted) {
      AppToast.show(context,
          message: AppStrings.of(context).fetchingAnalysis, type: ToastType.info);

      final provider = context.read<AnalysisProvider>();
      await provider.loadAnalyses();

      if (!context.mounted) return;

      final updatedAnalysis = provider.analyses
          .where((a) => a.recordingId == recording.id)
          .firstOrNull;

      if (updatedAnalysis != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  AnalysisScreen(analysisId: updatedAnalysis.id)),
        );
        return;
      }
    }

    // Failed, insufficient-audio, or pending — open lesson detail with retry button
    if (recording.isFailed || recording.isInsufficientAudio || recording.isPending) {
      final localPath =
          context.read<RecordingProvider>().getLocalFilePath(recording.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocalDraftDetailScreen(
            recording: recording,
            localFilePath: localPath,
          ),
        ),
      );
      return;
    }

    if (recording.isProcessing) {
      AppToast.show(
        context,
        message: 'This lesson is being analyzed. Please wait.',
        type: ToastType.info,
      );
    } else {
      AppToast.show(
        context,
        message: 'No analysis found. Try pulling down to refresh.',
        type: ToastType.info,
      );
    }
  }

  Future<void> _deleteRecording(
      BuildContext context, RecordingProvider provider, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).deleteRecording),
        content: Text(AppStrings.of(context).deleteRecordingMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.of(context).cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(AppStrings.of(context).delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.deleteRecording(id);
      if (context.mounted) {
        AppToast.show(context,
            message: AppStrings.of(context).recordingDeleted, type: ToastType.info);
      }
    }
  }

  /// Shows a dialog for a recording stuck at "pending" (uploaded but analysis
  /// was never triggered) and lets the teacher retry immediately.
  Future<void> _showRetryAnalysisDialog(
      BuildContext context, Recording recording) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).analysisNotStarted),
        content: Text(AppStrings.of(context).analysisNotStartedMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.of(context).cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.of(context).runAnalysis),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ApiService().analyzeRecording(recording.id);
        if (context.mounted) {
          AppToast.show(
            context,
            message: AppStrings.of(context).analysisStarted,
            type: ToastType.success,
            duration: const Duration(seconds: 4),
          );
          context.read<RecordingProvider>().startPollingIfNeeded();
        }
      } catch (e) {
        if (context.mounted) {
          AppToast.show(
            context,
            message: AppStrings.of(context).failedToStartAnalysis,
            type: ToastType.error,
          );
        }
      }
    }
  }
}

// ── Animated polling indicator dot ──────────────────────────────────────────
class _PollingDot extends StatefulWidget {
  @override
  State<_PollingDot> createState() => _PollingDotState();
}

class _PollingDotState extends State<_PollingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              AppTheme.warningColor.withValues(alpha: 0.4 + _ctrl.value * 0.6),
        ),
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull {
    var iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
