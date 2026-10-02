import 'package:flutter/material.dart';
import 'translations/en.dart';
import 'translations/pt.dart';
import 'translations/fr.dart';
import 'translations/am.dart';
import 'translations/sw.dart';

/// Central accessor for all user-facing strings.
///
/// Usage:
///   AppStrings.of(context).signIn
///   AppStrings.get(context, 'signIn')
///
/// The active language is driven by the [Locale] in the current [BuildContext].
/// Fall back to English for any missing key.
class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  /// Obtain the AppStrings instance from the nearest [Localizations] ancestor.
  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        AppStrings(const Locale('en'));
  }

  /// Raw map lookup — returns English fallback for unknown keys.
  static String get(BuildContext context, String key) {
    return AppStrings.of(context)._t(key);
  }

  // ── Internal map lookup ───────────────────────────────────────────────────

  static const Map<String, Map<String, String>> _maps = {
    'en': en,
    'pt': pt,
    'fr': fr,
    'am': am,
    'sw': sw,
  };

  String _t(String key) {
    final langCode = locale.languageCode;
    final map = _maps[langCode] ?? en;
    return map[key] ?? en[key] ?? key;
  }

  /// Look up a string by key at runtime.
  ///
  /// Used for TEACH element and behavior names, whose keys come from
  /// `core/teach/teach_elements.dart` rather than being known at compile time.
  /// Falls back to English, then to the key itself.
  String byKey(String key) => _t(key);

  /// Localized display letter for a stored H/M/L behavior rating.
  ///
  /// DISPLAY ONLY — the stored value is always "H"/"M"/"L". The dashboard, the
  /// Excel export and manual-score comparison all read the raw value, and colour
  /// selection still keys off it. Requested by the Mato Grosso coordinators, who
  /// need B/M/A (Baixo/Médio/Alto) in Portuguese.
  ///
  /// Note this is a per-value translation, not a reordering: "A" is High.
  /// Unknown values (including "N/A") pass through unchanged.
  String ratingLabel(String storedRating) {
    switch (storedRating.toUpperCase()) {
      case 'H':
        return _t('ratingHigh');
      case 'M':
        return _t('ratingMedium');
      case 'L':
        return _t('ratingLow');
      default:
        return storedRating;
    }
  }

  /// Coaching tip for a TEACH element, keyed by canonical element key
  /// (e.g. 'supportive_environment'). Returns null when no tip is defined, so
  /// callers can fall back to [askCoachTip].
  ///
  /// Tips are currently written in English and Portuguese only; other languages
  /// fall back to English via [_t] until a pedagogy reviewer signs them off.
  String? teachTip(String canonicalElementKey) {
    final key = 'teachTip_$canonicalElementKey';
    final langCode = locale.languageCode;
    final map = _maps[langCode] ?? en;
    return map[key] ?? en[key];
  }

  // ── General ───────────────────────────────────────────────────────────────
  String get appName => _t('appName');
  String get ok => _t('ok');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get close => _t('close');
  String get retry => _t('retry');
  String get loading => _t('loading');
  String get error => _t('error');
  String get success => _t('success');
  String get or => _t('or');
  String get sort => _t('sort');
  String get all => _t('all');
  String get yes => _t('yes');
  String get no => _t('no');
  String get back => _t('back');
  String get next => _t('next');
  String get done => _t('done');
  String get search => _t('search');
  String get copy => _t('copy');
  String get copiedToClipboard => _t('copiedToClipboard');
  String get notSet => _t('notSet');
  String get comingSoon => _t('comingSoon');

  // ── Offline Banner ────────────────────────────────────────────────────────
  String get offlineMessage => _t('offlineMessage');

  // ── Auth — Login ──────────────────────────────────────────────────────────
  String get welcomeBack => _t('welcomeBack');
  String get signInSubtitle => _t('signInSubtitle');
  String get username => _t('username');
  String get usernameHint => _t('usernameHint');
  String get password => _t('password');
  String get signIn => _t('signIn');
  String get forgotPassword => _t('forgotPassword');
  String get newUser => _t('newUser');
  String get createAccount => _t('createAccount');
  String get loginFailed => _t('loginFailed');
  String get enterUsername => _t('enterUsername');
  String get enterPassword => _t('enterPassword');
  String get copyright => _t('copyright');

  // ── Auth — Register ───────────────────────────────────────────────────────
  String get createAccountTitle => _t('createAccountTitle');
  String get joinCoach => _t('joinCoach');
  String get firstName => _t('firstName');
  String get lastName => _t('lastName');
  String get email => _t('email');
  String get emailOptional => _t('emailOptional');
  String get schoolName => _t('schoolName');
  String get schoolNameOptional => _t('schoolNameOptional');
  String get country => _t('country');
  String get register => _t('register');
  String get registrationFailed => _t('registrationFailed');
  String get enterFirstName => _t('enterFirstName');
  String get enterLastName => _t('enterLastName');
  String get enterEmail => _t('enterEmail');
  String get passwordMinLength => _t('passwordMinLength');
  String get selectCountry => _t('selectCountry');
  String get regStepCountryTitle => _t('regStepCountryTitle');
  String get regStepDetailsTitle => _t('regStepDetailsTitle');
  String get regStepAccountTitle => _t('regStepAccountTitle');
  String regStepIndicator(int current, int total) => _t('regStepIndicator')
      .replaceFirst('{current}', '$current')
      .replaceFirst('{total}', '$total');

  // ── Auth — Forgot / Reset Password ────────────────────────────────────────
  String get forgotPasswordTitle => _t('forgotPasswordTitle');
  String get forgotPasswordSubtitle => _t('forgotPasswordSubtitle');
  String get sendResetLink => _t('sendResetLink');
  String get resetPassword => _t('resetPassword');
  String get newPassword => _t('newPassword');
  String get confirmNewPassword => _t('confirmNewPassword');
  String get passwordsDoNotMatch => _t('passwordsDoNotMatch');

  // ── Onboarding ────────────────────────────────────────────────────────────
  String get onboardingWelcome => _t('onboardingWelcome');
  String get onboardingSubtitle => _t('onboardingSubtitle');
  String get onboardingContinue => _t('onboardingContinue');
  String get onboardingInfo => _t('onboardingInfo');
  String get enterSchoolName => _t('enterSchoolName');

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  String get navRecord => _t('navRecord');
  String get navMyLessons => _t('navMyLessons');
  String get navChats => _t('navChats');
  String get navProfile => _t('navProfile');

  // ── Home / Recording — Idle ───────────────────────────────────────────────
  String get tapToRecord => _t('tapToRecord');
  String get tapToRecordSub => _t('tapToRecordSub');
  String get tapToRecordButton => _t('tapToRecordButton');
  String get captureAudio => _t('captureAudio');
  String get importAudio => _t('importAudio');
  String get importAudioSub => _t('importAudioSub');

  // ── Home / Recording — Active ─────────────────────────────────────────────
  String get recording => _t('recording');
  String get recordingActive => _t('recordingActive');
  String get recordingPaused => _t('recordingPaused');
  String get pauseRecording => _t('pauseRecording');
  String get resumeRecording => _t('resumeRecording');
  String get stopRecording => _t('stopRecording');
  String get discardRecording => _t('discardRecording');
  String get discardRecordingMessage => _t('discardRecordingMessage');
  String get keep => _t('keep');
  String get discard => _t('discard');
  String get lockTooltip => _t('lockTooltip');
  String get unlockTooltip => _t('unlockTooltip');
  String get screenLocked => _t('screenLocked');

  // ── Home / Recording — Review ─────────────────────────────────────────────
  String get reviewRecording => _t('reviewRecording');
  String get lessonTitle => _t('lessonTitle');
  String get subject => _t('subject');
  String get gradeLevel => _t('gradeLevel');
  String get saveAndAnalyze => _t('saveAndAnalyze');
  String get saveLater => _t('saveLater');
  String get enterLessonTitle => _t('enterLessonTitle');
  String get selectSubject => _t('selectSubject');
  String get uploadingLesson => _t('uploadingLesson');
  String get uploadingSubtitle => _t('uploadingSubtitle');
  String get lessonSaved => _t('lessonSaved');
  String get uploadingForAnalysis => _t('uploadingForAnalysis');
  String get failedToSave => _t('failedToSave');
  String get failedToSaveLesson => _t('failedToSaveLesson');
  String get noInternetTitle => _t('noInternetTitle');
  String get noInternetAnalysis => _t('noInternetAnalysis');
  String get saveForLater => _t('saveForLater');
  String get recordingSavedToDevice => _t('recordingSavedToDevice');
  String get couldNotSaveRecording => _t('couldNotSaveRecording');
  String get importedAudioCopied => _t('importedAudioCopied');

  // ── Subjects ──────────────────────────────────────────────────────────────
  String get subjectMath => _t('subjectMath');
  String get subjectScience => _t('subjectScience');
  String get subjectEnglish => _t('subjectEnglish');
  String get subjectHistory => _t('subjectHistory');
  String get subjectArt => _t('subjectArt');
  String get subjectOther => _t('subjectOther');

  // ── My Lessons ────────────────────────────────────────────────────────────
  String get myLessons => _t('myLessons');
  String get searchLessons => _t('searchLessons');
  String get noLessonsFound => _t('noLessonsFound');
  String get analyzed => _t('analyzed');
  String get notAnalyzed => _t('notAnalyzed');
  String get sortBy => _t('sortBy');
  String get sortAlphabeticalAZ => _t('sortAlphabeticalAZ');
  String get sortAlphabeticalZA => _t('sortAlphabeticalZA');
  String get sortDateNewest => _t('sortDateNewest');
  String get sortDateOldest => _t('sortDateOldest');
  String get deleteRecording => _t('deleteRecording');
  String get deleteRecordingMessage => _t('deleteRecordingMessage');
  String get recordingDeleted => _t('recordingDeleted');
  String get analysisReady => _t('analysisReady');
  String get analysisCouldNotComplete => _t('analysisCouldNotComplete');
  String get tapToSeeDetails => _t('tapToSeeDetails');
  String get fetchingAnalysis => _t('fetchingAnalysis');
  String get lessonBeingAnalyzed => _t('lessonBeingAnalyzed');
  String get noAnalysisFound => _t('noAnalysisFound');
  String get analysisInProgress => _t('analysisInProgress');
  String get uploadingDrafts => _t('uploadingDrafts');
  String get analysisNotStarted => _t('analysisNotStarted');
  String get analysisNotStartedMessage => _t('analysisNotStartedMessage');
  String get runAnalysis => _t('runAnalysis');
  String get analysisStarted => _t('analysisStarted');
  String get failedToStartAnalysis => _t('failedToStartAnalysis');

  // ── Analysis Screen ───────────────────────────────────────────────────────
  String get lessonAnalysis => _t('lessonAnalysis');
  String get analysis => _t('analysis');
  String get overallScore => _t('overallScore');
  String get keyTakeaways => _t('keyTakeaways');
  String get strengths => _t('strengths');
  String get areasForImprovement => _t('areasForImprovement');
  String get recommendations => _t('recommendations');
  String get teachFramework => _t('teachFramework');
  String get scienceOfLearning => _t('scienceOfLearning');
  String get transcript => _t('transcript');
  String get transcriptComingSoon => _t('transcriptComingSoon');
  String get talkToCoach => _t('talkToCoach');
  String get copyAllFeedback => _t('copyAllFeedback');
  String get analysisCopied => _t('analysisCopied');
  String get lessonAudio => _t('lessonAudio');
  String get untitledLesson => _t('untitledLesson');
  String get shortRecording => _t('shortRecording');
  String get limitedTeachingActivity => _t('limitedTeachingActivity');
  String get lowAudioQuality => _t('lowAudioQuality');
  String get analysisNote => _t('analysisNote');
  String get coachFeedback => _t('coachFeedback');
  String get pros => _t('pros');
  String get cons => _t('cons');

  // ── Analysis — Element Detail ─────────────────────────────────────────────
  String get evidence => _t('evidence');
  String get behaviorFilter => _t('behaviorFilter');
  String get askCoachAbout => _t('askCoachAbout');
  /// Band for an element's 1-5 score, as a full word.
  ///
  /// Deliberately the same three-value vocabulary as the behaviour badges
  /// ([ratingLabel], which renders single letters) so the screen speaks one
  /// scale. The number itself is not shown — the World Bank asked for scores not
  /// to be surfaced directly.
  String scaleLabel(int score) {
    if (score >= 4) return _t('scaleHigh');
    if (score >= 3) return _t('scaleMedium');
    return _t('scaleLow');
  }
  String get rationale => _t('rationale');
  String get notObserved => _t('notObserved');
  String get tryThis => _t('tryThis');
  String get askTheCoach => _t('askTheCoach');
  String get askCoachTip => _t('askCoachTip');
  String get rating => _t('rating');
  String get evidenceFound => _t('evidenceFound');
  String get noDetailedAnalysis => _t('noDetailedAnalysis');

  // ── Analysis error screen ─────────────────────────────────────────────────
  String get analysisFailed => _t('analysisFailed');
  String get analysisCouldNotCompleteTitle => _t('analysisCouldNotCompleteTitle');
  String get retryAnalysis => _t('retryAnalysis');
  String get deleteRecordingAction => _t('deleteRecordingAction');
  String get analysisResubmitted => _t('analysisResubmitted');
  String get retryFailed => _t('retryFailed');
  String get actionCannotBeUndone => _t('actionCannotBeUndone');
  String deleteFailed(Object error) =>
      _t('deleteFailed').replaceFirst('{error}', '$error');

  /// Friendly message for a backend `failure_reason` code.
  ///
  /// [seconds] is the recording's duration, used to make the "too short"
  /// message specific. The backend sends its own English text in
  /// `error_message`; we deliberately do not use it, because it is never
  /// translated. See analysis_error_screen.dart.
  String failureMessage(String reason, {int? seconds}) {
    switch (reason) {
      case 'too_short':
        if (seconds != null && seconds > 0) {
          return _t('errTooShortWithDuration')
              .replaceFirst('{seconds}', '$seconds');
        }
        return _t('errTooShort');
      case 'file_too_small':
        return _t('errFileTooSmall');
      case 'file_too_large':
        return _t('errFileTooLarge');
      case 'poor_audio':
        return _t('errPoorAudio');
      case 'insufficient_content':
        return _t('errInsufficientContent');
      case 'token_limit_exceeded':
        return _t('errTokenLimit');
      case 'ai_service_error':
        return _t('errAiService');
      case 'network_error':
        return _t('errNetwork');
      case 'system_error':
      case 'storage_error':
      case 'database_error':
        return _t('errSystem');
      default:
        return _t('errUnknown');
    }
  }

  /// True when [failureMessage] has a specific translation for this reason.
  /// Used to decide whether the backend's untranslated text is worth showing.
  bool hasFailureMessage(String reason) => const {
        'too_short', 'file_too_small', 'file_too_large', 'poor_audio',
        'insufficient_content', 'token_limit_exceeded', 'ai_service_error',
        'network_error', 'system_error', 'storage_error', 'database_error',
      }.contains(reason);

  // ── Auth ──────────────────────────────────────────────────────────────────
  String get emailVerifiedSuccess => _t('emailVerifiedSuccess');
  String get verificationCodeSent => _t('verificationCodeSent');
  String get resetLinkSentIfExists => _t('resetLinkSentIfExists');
  String get togglePasswordVisibility => _t('togglePasswordVisibility');
  String get resetTokenLabel => _t('resetTokenLabel');
  String get resetTokenHelper => _t('resetTokenHelper');
  String get confirmPassword => _t('confirmPassword');
  String get passwordResetSuccessLogin => _t('passwordResetSuccessLogin');

  // ── Chat ──────────────────────────────────────────────────────────────────
  String deleteChatTitled(String title) =>
      _t('deleteChatTitled').replaceFirst('{title}', title);
  String get scrollToBottom => _t('scrollToBottom');
  String get moreOptions => _t('moreOptions');

  // ── Home / recording ──────────────────────────────────────────────────────
  String genericError(Object error) =>
      _t('genericError').replaceFirst('{error}', '$error');
  String errorImportingFile(Object error) =>
      _t('errorImportingFile').replaceFirst('{error}', '$error');
  String get discardRecordingTooltip => _t('discardRecordingTooltip');
  String get subjectHint => _t('subjectHint');
  String get openProfile => _t('openProfile');
  String get startRecordingLabel => _t('startRecordingLabel');
  String get stopRecordingLabel => _t('stopRecordingLabel');
  String get lastLesson => _t('lastLesson');
  String get weeklyStreak => _t('weeklyStreak');
  String get pleaseRecordOrSelect => _t('pleaseRecordOrSelect');
  String get startRecordingButton => _t('startRecordingButton');
  String get uploadFile => _t('uploadFile');
  String get descriptionOptional => _t('descriptionOptional');
  String get subjectOptional => _t('subjectOptional');
  String get gradeLevelOptional => _t('gradeLevelOptional');

  // ── Progress ──────────────────────────────────────────────────────────────
  String get completeAnalysesToSeeProgress => _t('completeAnalysesToSeeProgress');
  String get totalAnalyses => _t('totalAnalyses');
  String get averageScore => _t('averageScore');

  // ── Notifications (resolved without a BuildContext) ───────────────────────
  String get notifAnalysisReady => _t('notifAnalysisReady');
  String get notifAnalysisUnsuccessful => _t('notifAnalysisUnsuccessful');
  String get notifDefaultLessonTitle => _t('notifDefaultLessonTitle');

  String notifBodyAnalysed(String title) =>
      _t('notifBodyAnalysed').replaceFirst('{title}', title);

  String notifBodyFailed(String title, {String? reason}) {
    if (reason != null && reason.isNotEmpty) {
      return _t('notifBodyFailedWithReason')
          .replaceFirst('{title}', title)
          .replaceFirst('{reason}', reason);
    }
    return _t('notifBodyFailed').replaceFirst('{title}', title);
  }

  // ── Feedback audience ─────────────────────────────────────────────────────
  String get feedbackStyle => _t('feedbackStyle');
  String get feedbackStyleTeacher => _t('feedbackStyleTeacher');
  String get feedbackStyleCoordinator => _t('feedbackStyleCoordinator');
  String get feedbackStyleHelp => _t('feedbackStyleHelp');

  // ── Coaching conversation (coordinator flow) ──────────────────────────────
  String get coachConversation => _t('coachConversation');
  String get coachConversationSubtitle => _t('coachConversationSubtitle');
  String get coachPrepareButton => _t('coachPrepareButton');
  String get coachChooseFocalSkill => _t('coachChooseFocalSkill');
  String get coachChooseFocalSkillHelp => _t('coachChooseFocalSkillHelp');
  String get coachPrepared => _t('coachPrepared');
  String get coachGenerating => _t('coachGenerating');
  String get coachGenerateFailed => _t('coachGenerateFailed');
  String get coachRegenerate => _t('coachRegenerate');
  String get coachRegenerateConfirm => _t('coachRegenerateConfirm');
  String get coachNotAnalysedYet => _t('coachNotAnalysedYet');
  String get coachCopied => _t('coachCopied');

  String get coachBlockEvidence => _t('coachBlockEvidence');
  String get coachBlockMeaning => _t('coachBlockMeaning');
  String get coachBlockQuestion => _t('coachBlockQuestion');
  String get coachBlockFollowUps => _t('coachBlockFollowUps');
  String get coachBlockModel => _t('coachBlockModel');
  String get coachBlockPractice => _t('coachBlockPractice');
  String get coachBlockNextStep => _t('coachBlockNextStep');

  String get observedTeacher => _t('observedTeacher');
  String get observedTeacherHint => _t('observedTeacherHint');

  // ── Coaching areas ────────────────────────────────────────────────────────
  // Individual area labels are looked up dynamically as `coachArea_<key>` via
  // [byKey], because which areas exist is per-deployment configuration.
  String get prioritySkills => _t('prioritySkills');
  String get statePriorities => _t('statePriorities');
  String get allTeachElements => _t('allTeachElements');

  // ── Coordinator wording (selected via core/roles/role_copy.dart) ──────────
  String get navObserve => _t('navObserve');
  String get navObservedLessons => _t('navObservedLessons');
  String get tapToObserve => _t('tapToObserve');
  String get tapToObserveSub => _t('tapToObserveSub');
  String get noObservationsYet => _t('noObservationsYet');

  // ── Registration: role ────────────────────────────────────────────────────
  String get roleQuestion => _t('roleQuestion');
  String get roleTeacher => _t('roleTeacher');
  String get roleTeacherHelp => _t('roleTeacherHelp');
  String get roleCoordinator => _t('roleCoordinator');
  String get roleCoordinatorHelp => _t('roleCoordinatorHelp');

  // ── Email verification ────────────────────────────────────────────────────
  String get verificationFailed => _t('verificationFailed');
  String get failedToResendCode => _t('failedToResendCode');
  String get enterSixDigitCode => _t('enterSixDigitCode');
  String get pleaseEnterSixDigitCode => _t('pleaseEnterSixDigitCode');
  String get devPhaseEmailNotice => _t('devPhaseEmailNotice');

  // ── Reset password validators ─────────────────────────────────────────────
  String get pleaseEnterResetToken => _t('pleaseEnterResetToken');
  String get pleaseEnterNewPassword => _t('pleaseEnterNewPassword');
  String get passwordMinSixChars => _t('passwordMinSixChars');
  String get pleaseConfirmPassword => _t('pleaseConfirmPassword');

  // ── Network / API errors ──────────────────────────────────────────────────
  String get errCannotReachServer => _t('errCannotReachServer');
  String get errWrongCredentials => _t('errWrongCredentials');
  String get errAccountExists => _t('errAccountExists');
  String get errCheckInformation => _t('errCheckInformation');
  String get errServerError => _t('errServerError');
  String get errSomethingWentWrong => _t('errSomethingWentWrong');
  String get errCurrentPasswordIncorrect => _t('errCurrentPasswordIncorrect');

  /// Short hint appended to a failure notification, or null when the reason
  /// has no useful one-liner.
  String? notificationHint(String? reason) {
    switch (reason) {
      case 'too_short':
        return _t('notifHintTooShort');
      case 'poor_audio':
        return _t('notifHintPoorAudio');
      case 'file_too_large':
        return _t('notifHintFileTooLarge');
      default:
        return null;
    }
  }

  // ── TEACH element / behavior names ────────────────────────────────────────
  // Looked up dynamically via [byKey] using the labelKeys in
  // core/teach/teach_elements.dart, so they have no individual getters here.
  // teach_elements_test.dart asserts every one of them resolves in en and pt.

  // ── Chat Screen ───────────────────────────────────────────────────────────
  String get aiCoach => _t('aiCoach');
  String get viewLessonAnalysis => _t('viewLessonAnalysis');
  String get askAnything => _t('askAnything');
  String get typeMessage => _t('typeMessage');
  String get deleteConversation => _t('deleteConversation');
  String get deleteConversationMessage => _t('deleteConversationMessage');
  String get deleteConversationAction => _t('deleteConversationAction');
  String get permanentlyRemoveChat => _t('permanentlyRemoveChat');
  String get copyLogs => _t('copyLogs');
  String get copyLogsSubtitle => _t('copyLogsSubtitle');
  String get logLinesCopied => _t('logLinesCopied');

  // ── Chat Suggestions ──────────────────────────────────────────────────────
  String get suggestionEngagement => _t('suggestionEngagement');
  String get suggestionFocusNext => _t('suggestionFocusNext');
  String get suggestionExample => _t('suggestionExample');
  String get suggestionDidWell => _t('suggestionDidWell');

  // ── Chat List Screen ──────────────────────────────────────────────────────
  String get coaching => _t('coaching');
  String get newChat => _t('newChat');
  String get noChatsYet => _t('noChatsYet');
  String get startConversation => _t('startConversation');
  String get selectLesson => _t('selectLesson');
  String get generalChat => _t('generalChat');
  String get generalChatSubtitle => _t('generalChatSubtitle');

  // ── Profile Screen ────────────────────────────────────────────────────────
  String get editProfile => _t('editProfile');
  String get school => _t('school');
  String get darkMode => _t('darkMode');
  String get changePassword => _t('changePassword');
  String get logOut => _t('logOut');
  String get logOutConfirm => _t('logOutConfirm');
  String get saveChanges => _t('saveChanges');
  String get nameUpdated => _t('nameUpdated');
  String get updateFailed => _t('updateFailed');
  String get language => _t('language');

  // ── Profile — Change Password ─────────────────────────────────────────────
  String get changePasswordTitle => _t('changePasswordTitle');
  String get changePasswordSubtitle => _t('changePasswordSubtitle');
  String get currentPassword => _t('currentPassword');
  String get updatePassword => _t('updatePassword');
  String get enterCurrentPassword => _t('enterCurrentPassword');
  String get enterNewPassword => _t('enterNewPassword');
  String get atLeast6Chars => _t('atLeast6Chars');
  String get newPasswordMustDiffer => _t('newPasswordMustDiffer');
  String get passwordChanged => _t('passwordChanged');
  String get failedToChangePassword => _t('failedToChangePassword');

  // ── Email Verification ────────────────────────────────────────────────────
  String get verifyEmail => _t('verifyEmail');
  String get verificationCode => _t('verificationCode');
  String get resendCode => _t('resendCode');
  String get emailVerified => _t('emailVerified');
  String get verifyYourEmail => _t('verifyYourEmail');
  String get tapToSecureAccount => _t('tapToSecureAccount');
  String get verifyButton => _t('verifyButton');

  // ── Recording Screen ──────────────────────────────────────────────────────
  String get recordLesson => _t('recordLesson');
  String get newRecording => _t('newRecording');

  // ── Local Draft Detail ────────────────────────────────────────────────────
  String get localDraft => _t('localDraft');
  String get savedLocally => _t('savedLocally');
  String get uploadAndAnalyze => _t('uploadAndAnalyze');

  // ── Language Names ────────────────────────────────────────────────────────
  String get langEnglish => _t('langEnglish');
  String get langPortuguese => _t('langPortuguese');
  String get langFrench => _t('langFrench');
  String get langAmharic => _t('langAmharic');
  String get langSwahili => _t('langSwahili');

  // ── Analysis UI Labels ────────────────────────────────────────────────────
  String get notObservedSection => _t('notObservedSection');
  String tapToViewElements(int count) =>
      _t('tapToViewElements').replaceFirst('{count}', '$count');
  String get noneIdentified => _t('noneIdentified');
  String get growthAreas => _t('growthAreas');
  String get nextSteps => _t('nextSteps');
  String get example => _t('example');
  String get domainClassroomCulture => _t('domainClassroomCulture');
  String get domainInstruction => _t('domainInstruction');
  String get domainSocioemotionalSkills => _t('domainSocioemotionalSkills');
  String get clarityAndCognitiveLoad => _t('clarityAndCognitiveLoad');
  String get engagementAndRetrieval => _t('engagementAndRetrieval');
  String get feedbackAndMetacognition => _t('feedbackAndMetacognition');

  // ── Local Draft Detail Screen ──────────────────────────────────────────────
  String get draftSectionLessonDetails => _t('draftSectionLessonDetails');
  String get draftSectionLessonAudio => _t('draftSectionLessonAudio');
  String get draftSectionAnalysis => _t('draftSectionAnalysis');
  String get draftInfoTitle => _t('draftInfoTitle');
  String get draftInfoSubject => _t('draftInfoSubject');
  String get draftInfoGrade => _t('draftInfoGrade');
  String get draftInfoRecorded => _t('draftInfoRecorded');
  String get draftInfoDuration => _t('draftInfoDuration');
  String get draftInfoNotes => _t('draftInfoNotes');
  String get draftStatusSavedLocally => _t('draftStatusSavedLocally');
  String get draftStatusPending => _t('draftStatusPending');
  String get draftStatusFailed => _t('draftStatusFailed');
  String get draftStatusTooShort => _t('draftStatusTooShort');
  String draftUploadFailed(String error) => _t('draftUploadFailed').replaceFirst('{error}', error);
  String get draftUploadedAnalyzing => _t('draftUploadedAnalyzing');
  String get draftAnalysisRetriggered => _t('draftAnalysisRetriggered');
  String get draftRetryAnalysis => _t('draftRetryAnalysis');
  String get draftUploadingWait => _t('draftUploadingWait');
  String get draftStarting => _t('draftStarting');
  String get draftUploadInProgress => _t('draftUploadInProgress');
  String get draftIfKeepsFailing => _t('draftIfKeepsFailing');
  String get draftNoInternet => _t('draftNoInternet');
  String get draftNoInternetDetail => _t('draftNoInternetDetail');
  String get draftDataPersistenceNotice => _t('draftDataPersistenceNotice');
  String get draftLessonAudioLabel => _t('draftLessonAudioLabel');
}

// ── Localizations Delegate ────────────────────────────────────────────────────

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  static const List<String> _supported = ['en', 'pt', 'fr', 'am', 'sw'];

  @override
  bool isSupported(Locale locale) =>
      _supported.contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
