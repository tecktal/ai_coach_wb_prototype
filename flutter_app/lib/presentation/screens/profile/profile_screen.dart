import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/chat_provider.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../../widgets/verification_banner.dart';
import '../../widgets/country_dropdown.dart';
import '../../widgets/offline_banner.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showEditNameSheet(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final localeProvider = context.read<LocaleProvider>();
    final user = authProvider.user;
    final isDark = context.read<ThemeProvider>().isDark;

    final firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    final lastNameCtrl = TextEditingController(text: user?.lastName ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final schoolNameCtrl = TextEditingController(text: user?.schoolName ?? '');
    final countryCtrl = TextEditingController(text: user?.country ?? '');
    final formKey = GlobalKey<FormState>();
    String selectedLanguage = localeProvider.languageCode;
    String selectedAudience =
        authProvider.user?.feedbackAudience ?? FeedbackAudience.teacher;

    // Coordinators only — see the note at the picker below.
    final showFeedbackStyle = (authProvider.user?.isCoordinator ?? false) ||
        (authProvider.user?.isCoordinatorAudience ?? false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[600] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.of(context).editProfile,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CountryDropdown(
                    value: countryCtrl.text.isEmpty ? null : countryCtrl.text,
                    onChanged: (val) {
                      if (val != null) {
                        // Changing the country must NOT change the chosen
                        // language — they are decoupled once the profile exists.
                        countryCtrl.text = val;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context).language,
                      prefixIcon: const Icon(Icons.language_rounded),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'fr', child: Text('Français')),
                      DropdownMenuItem(value: 'pt', child: Text('Português')),
                      DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
                      DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() => selectedLanguage = val);
                        // Mark as an explicit user choice so it is never
                        // overridden by the country/server default again.
                        localeProvider.setLocale(val, userSelected: true);
                        // Persist immediately so the choice survives restarts
                        // even without pressing Save.
                        authProvider.updateProfile(languagePreference: val);
                      }
                    },
                  ),
                  // Who the AI writes its feedback for.
                  //
                  // Coordinators only. A teacher has nobody to coach, so the
                  // choice is meaningless to them and switching it would quietly
                  // break their own feedback.
                  //
                  // The audience check is deliberate as well as the role check:
                  // the Mato Grosso coordinators set this by hand before the
                  // coordinator role existed, and still carry role=teacher until
                  // an admin promotes them. Without it they would lose the
                  // ability to switch back.
                  if (showFeedbackStyle) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedAudience,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppStrings.of(context).feedbackStyle,
                        helperText: AppStrings.of(context).feedbackStyleHelp,
                        helperMaxLines: 3,
                        prefixIcon: const Icon(Icons.record_voice_over_outlined),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: FeedbackAudience.teacher,
                          child: Text(AppStrings.of(context).feedbackStyleTeacher),
                        ),
                        DropdownMenuItem(
                          value: FeedbackAudience.coordinator,
                          child: Text(AppStrings.of(context).feedbackStyleCoordinator),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedAudience = val);
                          // Persist immediately, matching the language picker.
                          authProvider.updateProfile(feedbackAudience: val);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: firstNameCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context).firstName,
                      prefixIcon: Icon(Icons.person_outline),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? AppStrings.of(context).enterFirstName : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context).lastName,
                      prefixIcon: Icon(Icons.person_outline),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? AppStrings.of(context).enterLastName : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context).emailOptional,
                      prefixIcon: Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null && v.isNotEmpty && !v.contains('@')) {
                        return AppStrings.of(context).enterEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: schoolNameCtrl,
                    decoration: InputDecoration(
                      labelText: AppStrings.of(context).school,
                      prefixIcon: Icon(Icons.school_outlined),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? AppStrings.of(context).enterSchoolName : null,
                  ),
                  const SizedBox(height: 24),
                  Consumer<AuthProvider>(
                    builder: (ctx, auth, _) {
                      return ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final success = await auth.updateProfile(
                                  firstName: firstNameCtrl.text.trim(),
                                  lastName: lastNameCtrl.text.trim(),
                                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                  schoolName: schoolNameCtrl.text.trim().isEmpty ? null : schoolNameCtrl.text.trim(),
                                  country: countryCtrl.text.trim().isEmpty ? null : countryCtrl.text.trim(),
                                  languagePreference: selectedLanguage,
                                );
                                if (!sheetCtx.mounted) return;
                                Navigator.pop(sheetCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? AppStrings.of(context).nameUpdated
                                            : (auth.error ?? AppStrings.of(context).updateFailed),
                                      ),
                                      backgroundColor:
                                          success ? Colors.green : Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                AppStrings.of(context).saveChanges,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDark;
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              // Lifts the sheet above the keyboard
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                // SingleChildScrollView prevents the 92px overflow when
                // keyboard opens and the sheet content is taller than available space
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppStrings.of(context).changePasswordTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.of(context).changePasswordSubtitle,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white54
                                  : AppTheme.textSub),
                        ),
                        const SizedBox(height: 20),

                        // Current password
                        TextFormField(
                          controller: currentCtrl,
                          obscureText: !showCurrent,
                          decoration: InputDecoration(
                            labelText: AppStrings.of(context).currentPassword,
                            prefixIcon:
                                const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: AppStrings.of(context).togglePasswordVisibility,
                              icon: Icon(showCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setSheetState(
                                  () => showCurrent = !showCurrent),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? AppStrings.of(context).enterCurrentPassword
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // New password
                        TextFormField(
                          controller: newCtrl,
                          obscureText: !showNew,
                          decoration: InputDecoration(
                            labelText: AppStrings.of(context).newPassword,
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              tooltip: AppStrings.of(context).togglePasswordVisibility,
                              icon: Icon(showNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () =>
                                  setSheetState(() => showNew = !showNew),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return AppStrings.of(context).enterNewPassword;
                            }
                            if (v.length < 6) return AppStrings.of(context).atLeast6Chars;
                            if (v == currentCtrl.text) {
                              return AppStrings.of(context).newPasswordMustDiffer;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Confirm password
                        TextFormField(
                          controller: confirmCtrl,
                          obscureText: !showConfirm,
                          decoration: InputDecoration(
                            labelText: AppStrings.of(context).confirmNewPassword,
                            prefixIcon:
                                const Icon(Icons.check_circle_outline),
                            suffixIcon: IconButton(
                              tooltip: AppStrings.of(context).togglePasswordVisibility,
                              icon: Icon(showConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setSheetState(
                                  () => showConfirm = !showConfirm),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (v) => v != newCtrl.text
                              ? AppStrings.of(context).passwordsDoNotMatch
                              : null,
                        ),
                        const SizedBox(height: 24),

                        Consumer<AuthProvider>(
                          builder: (ctx, auth, _) => ElevatedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate())
                                      return;
                                    final ok = await auth.changePassword(
                                      currentCtrl.text,
                                      newCtrl.text,
                                    );
                                    if (!sheetCtx.mounted) return;
                                    Navigator.pop(sheetCtx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(ok
                                              ? AppStrings.of(context).passwordChanged
                                              : (auth.error ??
                                                  AppStrings.of(context).failedToChangePassword)),
                                          backgroundColor:
                                              ok ? Colors.green : Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : Text(AppStrings.of(context).updatePassword,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;

    // Resolve flag from country
    final userCountry = user?.country;
    final flag = countryFlag(userCountry);
    final countryDisplay = userCountry != null && userCountry.isNotEmpty
        ? (flag.isEmpty ? userCountry : '$flag  $userCountry')
        : 'Not set';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Offline indicator — slides in when no internet
            const OfflineBanner(),
            // Email verification nudge
            if (user != null && !user.emailVerified)
              VerificationBanner(user: user),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Avatar
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: Border.all(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                            width: 3),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color:
                                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                      ),
                      child: Icon(Icons.person_rounded,
                          size: 50, color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(height: 16),

                    // Name row with edit button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            '${user?.firstName ?? ''} ${user?.lastName ?? ''}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.textMain,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: AppStrings.of(context).editProfile,
                          child: GestureDetector(
                            onTap: () => _showEditNameSheet(context),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_outlined,
                                  size: 16, color: Theme.of(context).primaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user?.username ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (user?.email != null && user!.email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.email!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  isDark ? Colors.grey[400] : AppTheme.textSub,
                            ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Info Section
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark
                                ? Colors.transparent
                                : Colors.grey.shade100),
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
                      child: Column(
                        children: [
                          _buildProfileItem(
                              context,
                              Icons.school_outlined,
                              AppStrings.of(context).school,
                              (user?.schoolName != null && user!.schoolName!.isNotEmpty) ? user.schoolName! : AppStrings.of(context).notSet,
                              isDark),
                          _buildDivider(isDark),
                          _buildProfileItem(
                              context,
                              Icons.public,
                              AppStrings.of(context).country,
                              countryDisplay,
                              isDark),
                          _buildDivider(isDark),
                          _buildProfileItem(
                              context,
                              Icons.translate_rounded,
                              AppStrings.of(context).language,
                              context.watch<LocaleProvider>().languageName,
                              isDark),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Theme Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark
                                ? Colors.transparent
                                : Colors.grey.shade100),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isDark
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              AppStrings.of(context).darkMode,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.textMain,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: isDark,
                              onChanged: (_) => themeProvider.toggleTheme(),
                              activeTrackColor: Theme.of(context).primaryColor,
                              thumbColor: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.selected)
                                    ? Colors.white
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Change Password
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark
                                ? Colors.transparent
                                : Colors.grey.shade100),
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
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showChangePasswordSheet(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.password_rounded,
                                    color: Theme.of(context).primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  AppStrings.of(context).changePassword,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textMain,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              title: Text(AppStrings.of(context).logOut,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textMain)),
                              content: Text(
                                  AppStrings.of(context).logOutConfirm,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : AppTheme.textMain)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(AppStrings.of(context).cancel),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.errorColor),
                                  child: Text(AppStrings.of(context).logOut),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && context.mounted) {
                            // Clear all in-memory state so the next account
                            // never sees this user's data (chat, recordings).
                            context.read<RecordingProvider>().clearForLogout();
                            context.read<ChatProvider>().clearUserData();
                            await context.read<AuthProvider>().logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.errorColor.withValues(alpha: 0.1),
                          foregroundColor: AppTheme.errorColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide.none,
                          ),
                        ),
                        child: Text(
                          AppStrings.of(context).logOut,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(
      BuildContext context, IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textMain,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : AppTheme.textSub,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? Colors.grey[800] : Colors.grey.shade100,
      indent: 20,
      endIndent: 20,
    );
  }
}
