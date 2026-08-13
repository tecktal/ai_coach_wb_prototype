import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/chat_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/offline_banner.dart';
import 'chat_screen.dart';

enum _ChatSortOption { dateNewest, dateOldest, alphabeticalAZ, alphabeticalZA }

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  _ChatSortOption _currentSort = _ChatSortOption.dateNewest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadSessions();
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getTitle(Map<String, dynamic> session) {
    if (session['subject'] != null && session['subject'].toString().isNotEmpty) {
      String t = session['subject'];
      if (session['grade_level'] != null) t += ' • ${session['grade_level']}';
      return t;
    }
    return session['lesson_title'] ?? 'General Chat';
  }

  String _getSubtitle(Map<String, dynamic> session) {
    final date = DateTime.parse(session['created_at']);
    final formatted = DateFormat('MMM d • h:mm a').format(date);
    if (session['subject'] != null &&
        session['lesson_title'] != null &&
        !(session['lesson_title'] as String).contains('202')) {
      return session['lesson_title'];
    }
    return formatted;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> sessions) {
    var list = sessions.where((s) {
      final title = _getTitle(s).toLowerCase();
      final subtitle = _getSubtitle(s).toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || subtitle.contains(q);
    }).toList();

    if (_selectedCategory != 'All') {
      list = list.where((s) {
        final subject = (s['subject'] ?? '').toString().toLowerCase();
        return subject.contains(_selectedCategory.toLowerCase());
      }).toList();
    }

    list.sort((a, b) {
      switch (_currentSort) {
        case _ChatSortOption.dateNewest:
          return DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']));
        case _ChatSortOption.dateOldest:
          return DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']));
        case _ChatSortOption.alphabeticalAZ:
          return _getTitle(a).compareTo(_getTitle(b));
        case _ChatSortOption.alphabeticalZA:
          return _getTitle(b).compareTo(_getTitle(a));
      }
    });

    return list;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        Widget tile(String label, IconData icon, _ChatSortOption opt) {
          final selected = _currentSort == opt;
          return ListTile(
            leading: Icon(icon, color: selected ? Theme.of(context).primaryColor : (isDark ? Colors.grey[400] : Colors.grey)),
            title: Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Theme.of(context).primaryColor : (isDark ? Colors.white : AppTheme.textMain),
                )),
            trailing: selected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
            onTap: () {
              setState(() => _currentSort = opt);
              Navigator.pop(ctx);
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 16),
                child: Text(AppStrings.of(ctx).sortBy,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              tile(AppStrings.of(context).sortDateNewest, Icons.calendar_today, _ChatSortOption.dateNewest),
              tile(AppStrings.of(context).sortDateOldest, Icons.calendar_today, _ChatSortOption.dateOldest),
              tile(AppStrings.of(context).sortAlphabeticalAZ, Icons.sort_by_alpha, _ChatSortOption.alphabeticalAZ),
              tile(AppStrings.of(context).sortAlphabeticalZA, Icons.sort_by_alpha, _ChatSortOption.alphabeticalZA),
            ],
          ),
        );
      },
    );
  }

  void _deleteSession(String sessionId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).deleteConversation),
        content: Text(AppStrings.of(context).deleteChatTitled(title)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.of(context).cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: Text(AppStrings.of(context).delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ChatProvider>().deleteSession(sessionId);
      if (mounted) {
        context.read<ChatProvider>().loadSessions();
        AppToast.show(context, message: 'Chat deleted.', type: ToastType.info);
      }
    }
  }

  void _openChat(String? analysisId, {String? sessionId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(analysisId: analysisId, sessionId: sessionId),
      ),
    ).then((_) {
      if (mounted) context.read<ChatProvider>().loadSessions();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.of(context).coaching,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textMain,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.sessions.isEmpty) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
          }

          final filtered = _filtered(provider.sessions.cast<Map<String, dynamic>>());

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Offline indicator — slides in when device has no internet
                const OfflineBanner(),
                // ── Search & Filters ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(color: isDark ? Colors.white : AppTheme.textMain),
                          decoration: InputDecoration(
                            hintText: AppStrings.of(context).search,
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey.shade400),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Category + Sort row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Category filter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isDense: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                icon: Icon(Icons.keyboard_arrow_down, size: 18, color: Theme.of(context).primaryColor),
                                style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                                items: ['All', 'Math', 'Science', 'English', 'History', 'Art'].map((v) {
                                  return DropdownMenuItem<String>(value: v, child: Text(v));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCategory = val);
                                },
                              ),
                            ),
                          ),
                          // Sort button
                          TextButton.icon(
                            onPressed: _showSortOptions,
                            icon: Icon(Icons.sort_rounded, size: 18),
                            label: Text(AppStrings.of(context).sort),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── List ─────────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 64,
                                  color: isDark ? Colors.grey[700] : Colors.grey.shade200),
                              const SizedBox(height: 16),
                              Text(
                                provider.sessions.isEmpty
                                    ? AppStrings.of(context).noChatsYet
                                    : AppStrings.of(context).search,
                                style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: Theme.of(context).primaryColor,
                          onRefresh: () => context.read<ChatProvider>().loadSessions(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final session = filtered[index];
                              final title = _getTitle(session);
                              final subtitle = _getSubtitle(session);
                              final date = DateTime.parse(session['created_at']);

                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
                                  boxShadow: isDark ? [] : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.school, color: Theme.of(context).primaryColor, size: 20),
                                  ),
                                  title: Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : AppTheme.textMain,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subtitle,
                                            style: TextStyle(
                                              color: isDark ? Colors.grey[400] : AppTheme.textSub,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat('MMM d').format(date),
                                          style: TextStyle(
                                            color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Icon(Icons.chevron_right, size: 18,
                                      color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                  onTap: () => _openChat(null, sessionId: session['id']),
                                  onLongPress: () => _deleteSession(session['id'], title),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
