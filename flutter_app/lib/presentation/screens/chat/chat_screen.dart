import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../data/providers/chat_provider.dart';
import '../../../data/models/chat_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/connectivity_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../analysis/analysis_screen.dart';
import '../../widgets/offline_banner.dart';
import '../../../core/l10n/app_strings.dart';

class ChatScreen extends StatefulWidget {
  final String? analysisId;
  final String? sessionId;
  /// If set, pre-fills the message input so the teacher can send it immediately.
  final String? initialMessage;

  const ChatScreen({super.key, this.analysisId, this.sessionId, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _analysisId;
  late final _KeyboardScrollObserver _keyboardObserver;

  // Throttle guard — only one scroll-to-bottom scheduled per frame
  bool _autoScrollPending = false;

  // Whether to show the FAB "scroll to bottom" button
  bool _showScrollFab = false;

  List<String> _getSuggestions(BuildContext context) {
    return [
      AppStrings.of(context).suggestionEngagement,
      AppStrings.of(context).suggestionFocusNext,
      AppStrings.of(context).suggestionExample,
      AppStrings.of(context).suggestionDidWell,
    ];
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _analysisId = widget.analysisId;

    // Pre-fill message if the screen was opened with an initial question
    if (widget.initialMessage != null) {
      _controller.text = widget.initialMessage!;
    }

    _scrollController.addListener(_onScroll);

    // When keyboard opens, scroll to bottom so the last message stays visible
    _keyboardObserver = _KeyboardScrollObserver(
      onKeyboardOpen: () {
        // Small delay lets the layout settle after keyboard animation
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _scrollController.hasClients) {
            _jumpToBottom();
          }
        });
      },
    );
    WidgetsBinding.instance.addObserver(_keyboardObserver);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.sessionId != null) {
        _loadSessionAndExtractAnalysisId();
      } else {
        _initNewSession();
      }
    });
  }

  Future<void> _initNewSession() async {
    await context.read<ChatProvider>().initSession(widget.analysisId);
    // After messages load, jump to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  Future<void> _loadSessionAndExtractAnalysisId() async {
    final provider = context.read<ChatProvider>();
    await provider.loadChatSession(widget.sessionId!);

    if (provider.sessions.isNotEmpty) {
      final session = provider.sessions.firstWhere(
        (s) => s['id'] == widget.sessionId,
        orElse: () => null,
      );
      if (session != null && session['analysis_id'] != null && mounted) {
        setState(() => _analysisId = session['analysis_id']);
      }
    }

    // Jump to bottom after message history loads
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_keyboardObserver);
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll helpers ────────────────────────────────────────────────────────

  void _onScroll() {
    final shouldShow = !_isNearBottom();
    if (shouldShow != _showScrollFab) {
      setState(() => _showScrollFab = shouldShow);
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final max = _scrollController.position.maxScrollExtent;
    final pos = _scrollController.offset;
    return (max - pos) < 180;
  }

  /// Instant jump — used for auto-follow during streaming (no animation queue buildup)
  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  /// Animated — used for user-triggered FAB tap
  void _animateToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Called from Consumer builder — throttled to one frame to avoid stacking hundreds of callbacks
  void _scheduleAutoScrollIfNearBottom() {
    if (_autoScrollPending) return;
    _autoScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollPending = false;
      if (mounted && _isNearBottom()) {
        _jumpToBottom();
      }
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _handleSend([String? suggestion]) {
    final textToSend = suggestion ?? _controller.text.trim();
    if (textToSend.isEmpty) return;

    final locale = Localizations.localeOf(context).languageCode;
    context.read<ChatProvider>().sendMessage(textToSend, language: locale);
    _controller.clear();
    // Schedule scroll after the new message widget is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).copiedToClipboard),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteChat() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.errorColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(AppStrings.of(context).deleteConversation,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textMain)),
              const SizedBox(height: 8),
              Text(AppStrings.of(context).deleteConversationMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : AppTheme.textSub,
                      height: 1.5)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300),
                        foregroundColor:
                            isDark ? Colors.white70 : AppTheme.textSub),
                    child: Text(AppStrings.of(context).cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0),
                    child: Text(AppStrings.of(context).delete,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final sessionId = context.read<ChatProvider>().currentSessionId;
      if (sessionId != null) {
        await context.read<ChatProvider>().deleteSession(sessionId);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  void _showChatOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4))
            ]),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteChat();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                AppTheme.errorColor.withValues(alpha: 0.15))),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color:
                                AppTheme.errorColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.errorColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(AppStrings.of(context).deleteConversation,
                            style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(AppStrings.of(context).permanentlyRemoveChat,
                            style: TextStyle(
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.7),
                                fontSize: 12)),
                      ]),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color:
                              AppTheme.errorColor.withValues(alpha: 0.5),
                          size: 20),
                    ]),
                  ),
                ),
              ),
            ),
            // ── Copy Logs (debug helper) ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final logs = AppLogger.dump();
                    await Clipboard.setData(ClipboardData(text: logs));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${logs.split('\n').length} log lines copied to clipboard'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.15))),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.copy_all_rounded, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(AppStrings.of(context).copyLogs,
                            style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(AppStrings.of(context).copyLogsSubtitle,
                            style: TextStyle(
                                color: Colors.blue.withValues(alpha: 0.7),
                                fontSize: 12)),
                      ]),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.blue.withValues(alpha: 0.5), size: 20),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // ── Cancel ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade100,
                      foregroundColor:
                          isDark ? Colors.white70 : AppTheme.textSub),
                  child: Text(AppStrings.of(context).cancel,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Scroll-to-bottom FAB
      floatingActionButton: _showScrollFab
          ? Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton.small(
                tooltip: AppStrings.of(context).scrollToBottom,
                onPressed: _animateToBottom,
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                elevation: 3,
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
              ),
            )
          : null,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: IconButton(
          tooltip: AppStrings.of(context).back,
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color:
                    Theme.of(context).primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(Icons.smart_toy_outlined,
                size: 15, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 8),
          Text(AppStrings.of(context).aiCoach,
              style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ]),
        actions: [
          IconButton(
            tooltip: AppStrings.of(context).moreOptions,
            icon: Icon(Icons.more_horiz,
                color: isDark ? Colors.white70 : AppTheme.textSub),
            onPressed: _showChatOptions,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.grey.shade100,
              height: 1),
        ),
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          // Throttled auto-scroll — only one callback registered per frame,
          // uses jumpTo (instant) to prevent animation queue buildup
          if (provider.isStreaming) {
            _scheduleAutoScrollIfNearBottom();
          }

          return Column(children: [
            // Offline indicator — slides in when no internet
            const OfflineBanner(),

            // ── Analysis link ──
            if (_analysisId != null)
              Material(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
                child: InkWell(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) =>
                              AnalysisScreen(analysisId: _analysisId!))),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.12)))),
                    child: Row(children: [
                      Icon(Icons.analytics_outlined,
                          size: 15, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(AppStrings.of(context).viewLessonAnalysis,
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                      Icon(Icons.arrow_forward_ios,
                          size: 11,
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.6)),
                    ]),
                  ),
                ),
              ),

            // ── Messages ──
            Expanded(
              child: provider.messages.isEmpty && !provider.isLoading
                  ? SingleChildScrollView(
                      child: _buildEmptyState(provider, isDark))
                  : ListView.builder(
                      controller: _scrollController,
                      // cacheExtent prevents items from being destroyed when
                      // scrolling up, reducing rebuild cost
                      cacheExtent: 1000,
                      padding:
                          const EdgeInsets.only(top: 16, bottom: 16),
                      itemCount: provider.messages.length +
                          (provider.isLoading &&
                                  provider.messages.isNotEmpty &&
                                  provider.messages.last.role == 'user'
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index == provider.messages.length) {
                          return const _TypingIndicator();
                        }

                        final message = provider.messages[index];
                        if (message.role != 'user' &&
                            message.content.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return _buildMessage(message, isDark);
                      },
                    ),
            ),

            _buildInputArea(provider, isDark),
          ]);
        },
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(ChatProvider provider, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 52, 28, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
              color:
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome_outlined,
              size: 32,
              color: Theme.of(context)
                  .primaryColor
                  .withValues(alpha: 0.85)),
        ),
        const SizedBox(height: 20),
        Text(AppStrings.of(context).aiCoach,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textMain)),
        const SizedBox(height: 6),
        Text(AppStrings.of(context).askAnything,
            style: TextStyle(
                color: isDark ? Colors.grey[400] : AppTheme.textSub,
                fontSize: 14,
                height: 1.65),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children:
              _getSuggestions(context).map((s) => _buildChip(provider, s, isDark)).toList(),
        ),
      ]),
    );
  }

  Widget _buildChip(ChatProvider provider, String text, bool isDark) {
    return ActionChip(
      label: Text(text,
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500)),
      backgroundColor:
          Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.14 : 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.22)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _handleSend(text),
    );
  }

  // ── Message widgets ───────────────────────────────────────────────────────

  Widget _buildMessage(ChatMessage message, bool isDark) {
    return message.role == 'user'
        ? _buildUserBubble(message, isDark)
        : _buildAssistantMessage(message, isDark);
  }

  Widget _buildUserBubble(ChatMessage message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 2, 16, 20),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                  color: Theme.of(context)
                      .primaryColor
                      .withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Text(message.content,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.55)),
        ),
      ),
    );
  }

  Widget _buildAssistantMessage(ChatMessage message, bool isDark) {
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : const Color(0xFF1A1A2E);
    final mutedColor = isDark ? Colors.white38 : Colors.grey.shade400;
    final codeBackground =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final codeBorder = isDark ? Colors.white12 : Colors.grey.shade200;

    final styleSheet = MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 16, height: 1.72),
      strong: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w700),
      em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      h1: TextStyle(
          color: isDark ? Colors.white : AppTheme.textMain,
          fontWeight: FontWeight.bold,
          fontSize: 22,
          height: 1.4),
      h2: TextStyle(
          color: isDark ? Colors.white : AppTheme.textMain,
          fontWeight: FontWeight.bold,
          fontSize: 19,
          height: 1.4),
      h3: TextStyle(
          color: isDark ? Colors.white : AppTheme.textMain,
          fontWeight: FontWeight.bold,
          fontSize: 17,
          height: 1.4),
      listBullet:
          TextStyle(color: textColor, fontSize: 16, height: 1.72),
      blockquoteDecoration: BoxDecoration(
        border: Border(
            left: BorderSide(
                color: Theme.of(context)
                    .primaryColor
                    .withValues(alpha: 0.5),
                width: 3)),
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius:
            const BorderRadius.horizontal(right: Radius.circular(4)),
      ),
      blockquote: TextStyle(
          color: textColor, fontSize: 15, fontStyle: FontStyle.italic),
      code: TextStyle(
          color: textColor,
          backgroundColor: codeBackground,
          fontFamily: 'monospace',
          fontSize: 14),
      codeblockDecoration: BoxDecoration(
          color: codeBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: codeBorder)),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar + label
        Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: Theme.of(context)
                    .primaryColor
                    .withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.smart_toy_outlined,
                size: 14, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(width: 8),
          Text(AppStrings.of(context).aiCoach,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.2)),
        ]),
        const SizedBox(height: 10),

        // Message body — always rendered as selectable since responses
        // are now only added once fully buffered (no mid-stream partial markdown).
        MarkdownBody(
          data: message.content,
          selectable: true,
          styleSheet: styleSheet,
          builders: {
            'latex': LatexElementBuilder(
              textStyle: TextStyle(
                color: textColor,
              ),
            ),
          },
          extensionSet: md.ExtensionSet(
            [LatexBlockSyntax(), ...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
            [LatexInlineSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
          ),
        ),

        // Copy button
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: AppStrings.of(context).copy,
          child: GestureDetector(
            onTap: () => _copyMessage(message.content),
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.copy_outlined, size: 14, color: mutedColor),
                  const SizedBox(width: 5),
                  Text(AppStrings.of(context).copy,
                      style: TextStyle(
                          fontSize: 12,
                          color: mutedColor,
                          fontWeight: FontWeight.w500)),
                ]),
            ),
          ),
        ),
      ]),
    );
  }


  // ── Input bar ─────────────────────────────────────────────────────────────

  Widget _buildInputArea(ChatProvider provider, bool isDark) {
    final isOnline = context.read<ConnectivityProvider>().isOnline;
    final bool canSend = !provider.isLoading && isOnline;

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final fieldBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8F9FB);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.09) : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
            top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.grey.shade100)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: borderColor)),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: AppStrings.of(context).typeMessage,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                          color:
                              isDark ? Colors.grey[600] : Colors.grey[400],
                          fontSize: 15),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textMain,
                        fontSize: 15,
                        height: 1.4),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    onSubmitted: (_) => canSend ? _handleSend() : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canSend ? _handleSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend
                        ? Theme.of(context).primaryColor
                        : (isDark
                            ? Colors.grey[800]
                            : Colors.grey.shade200),
                    boxShadow: canSend
                        ? [
                            BoxShadow(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: Center(
                    child: provider.isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400]))
                        : const Icon(Icons.arrow_upward_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Blinking cursor — isolated stateful widget so it NEVER causes parent rebuild ──
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _visible ? '▌' : ' ',
      style: TextStyle(
        color: Theme.of(context).primaryColor,
        fontSize: 18,
        height: 1,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: Theme.of(context)
                  .primaryColor
                  .withValues(alpha: isDark ? 0.2 : 0.1),
              shape: BoxShape.circle),
          child: Icon(Icons.smart_toy_outlined,
              size: 14, color: Theme.of(context).primaryColor),
        ),
        const SizedBox(width: 12),
        Row(
          children: List.generate(3, (i) {
            return FadeTransition(
              opacity: Tween(begin: 0.25, end: 1.0).animate(CurvedAnimation(
                parent: _controller,
                curve: Interval(i * 0.2, 0.6 + i * 0.2,
                    curve: Curves.easeInOut),
              )),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    shape: BoxShape.circle),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

/// Watches for keyboard open/close via [WidgetsBindingObserver.didChangeMetrics].
/// Calls [onKeyboardOpen] when the keyboard inset increases significantly.
class _KeyboardScrollObserver extends WidgetsBindingObserver {
  final VoidCallback onKeyboardOpen;
  double _prevInset = 0;

  _KeyboardScrollObserver({required this.onKeyboardOpen});

  @override
  void didChangeMetrics() {
    final inset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    if (inset > _prevInset + 50) {
      // Keyboard just opened
      onKeyboardOpen();
    }
    _prevInset = inset;
  }
}
