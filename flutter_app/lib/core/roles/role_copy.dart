import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/providers/auth_provider.dart';
import '../l10n/app_strings.dart';

/// Every user-facing string that reads differently for a coordinator.
///
/// A coordinator records lessons that someone else taught, so "Record" and
/// "My Lessons" are wrong for them — the app should speak about observation.
///
/// The point of putting it all here is that one file answers "what does this
/// say for this role". Scattering `if (isCoordinator)` across screens makes the
/// divergence impossible to see, and B2b and B4 both extend it.
class RoleCopy {
  final AppStrings _strings;

  /// Whether the signed-in account is a pedagogy coordinator.
  final bool isCoordinator;

  const RoleCopy._(this._strings, this.isCoordinator);

  /// Reads the role from [AuthProvider]. Defaults to the teacher wording when
  /// nobody is signed in, which is the safe direction — a teacher never sees
  /// coordinator language by accident.
  factory RoleCopy.of(BuildContext context, {bool listen = true}) {
    final auth = listen
        ? context.watch<AuthProvider>()
        : context.read<AuthProvider>();
    return RoleCopy._(
      AppStrings.of(context),
      auth.user?.isCoordinator ?? false,
    );
  }

  String _pick(String teacher, String coordinator) =>
      isCoordinator ? coordinator : teacher;

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// "Record" → "Observe"
  String get navRecord =>
      _pick(_strings.navRecord, _strings.navObserve);

  /// "My Lessons" → "Observed Lessons"
  String get navLessons =>
      _pick(_strings.navMyLessons, _strings.navObservedLessons);

  // ── Recording screen ───────────────────────────────────────────────────────

  /// Headline above the record button.
  String get recordPrompt =>
      _pick(_strings.tapToRecord, _strings.tapToObserve);

  /// Supporting line under it.
  String get recordPromptSub =>
      _pick(_strings.tapToRecordSub, _strings.tapToObserveSub);

  // ── Lesson list ────────────────────────────────────────────────────────────

  /// Title of the lessons list.
  String get lessonsTitle =>
      _pick(_strings.navMyLessons, _strings.navObservedLessons);

  /// Empty state when no lessons exist yet.
  String get lessonsEmpty =>
      _pick(_strings.noLessonsFound, _strings.noObservationsYet);
}
