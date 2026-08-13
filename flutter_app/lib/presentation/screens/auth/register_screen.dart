import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../presentation/widgets/country_customization.dart';
import '../../widgets/country_dropdown.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // One State object keeps all entered data alive across steps.
  static const int _totalSteps = 3;

  final _pageController = PageController();
  // Steps 2 and 3 each validate only their own visible fields.
  final _detailsFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _countryController = TextEditingController();

  int _currentStep = 0;
  bool _obscurePassword = true;
  String? _selectedLanguage; // auto-detected from country, user-overridable
  String? _countryError;

  /// Teacher unless the user says otherwise. The question is only shown in
  /// countries where the programme runs coordinators; everywhere else this
  /// stays 'teacher' and is never surfaced.
  String _selectedRole = UserRole.teacher;

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _schoolController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  // ── Localization on country/language change ─────────────────────────────────

  void _onCountrySelected(String? value) {
    if (value == null) return;
    final code = CountryCustomization.getLanguageCode(value);
    setState(() {
      _countryController.text = value;
      _selectedLanguage = code;
      _countryError = null;
      // Switching to a country without coordinators hides the question, so
      // clear any earlier choice rather than submitting an invisible one.
      if (!CountryCustomization.offersCoordinatorRole(value)) {
        _selectedRole = UserRole.teacher;
      }
    });
    // Step 1 is a deliberate country choice, so translating now is intended:
    // every following step renders in the chosen language.
    context.read<LocaleProvider>().setLocaleFromCountry(value);
  }

  void _onLanguageSelected(String? value) {
    if (value == null) return;
    setState(() => _selectedLanguage = value);
    context.read<LocaleProvider>().setLocale(value);
  }

  // ── Step navigation ─────────────────────────────────────────────────────────

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _next() {
    switch (_currentStep) {
      case 0:
        if (_countryController.text.trim().isEmpty) {
          setState(() => _countryError = AppStrings.of(context).selectCountry);
          return;
        }
        _goToPage(1);
        break;
      case 1:
        if (!_detailsFormKey.currentState!.validate()) return;
        _goToPage(2);
        break;
    }
  }

  void _back() {
    if (_currentStep > 0) _goToPage(_currentStep - 1);
  }

  Future<void> _register() async {
    if (!_accountFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final country = _countryController.text.trim().isEmpty
        ? null
        : _countryController.text.trim();
    final langCode =
        _selectedLanguage ?? CountryCustomization.getLanguageCode(country);
    final success = await authProvider.register({
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'password': _passwordController.text,
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'school_name': _schoolController.text.trim().isEmpty
          ? null
          : _schoolController.text.trim(),
      'country': country,
      'language_preference': langCode,
      // Backend re-validates this — only teacher/coordinator are honoured, so a
      // tampered client cannot self-assign a dashboard role.
      'role': _selectedRole,
    });

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              authProvider.error ?? AppStrings.of(context).registrationFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return PopScope(
      // While past step 1, intercept back to move to the previous step instead
      // of popping the whole screen.
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.createAccountTitle),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildProgress(context),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    _buildCountryStep(context),
                    _buildDetailsStep(context),
                    _buildAccountStep(context),
                  ],
                ),
              ),
              _buildNavButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(_totalSteps, (i) {
              final active = i <= _currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == _totalSteps - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: active
                        ? primary
                        : primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.of(context).regStepIndicator(_currentStep + 1, _totalSteps),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCountryStep(BuildContext context) {
    final strings = AppStrings.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.regStepCountryTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.joinCoach,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          CountryDropdown(
            value: _countryController.text.isEmpty
                ? null
                : _countryController.text,
            onChanged: _onCountrySelected,
            errorText: _countryError,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedLanguage,
            decoration: InputDecoration(
              labelText: strings.language,
              prefixIcon: const Icon(Icons.language_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'fr', child: Text('Français')),
              DropdownMenuItem(value: 'pt', child: Text('Português')),
              DropdownMenuItem(value: 'sw', child: Text('Kiswahili')),
              DropdownMenuItem(value: 'am', child: Text('አማርኛ')),
            ],
            onChanged: _onLanguageSelected,
          ),

          // Only offered where the programme runs coordinators — elsewhere the
          // role defaults to teacher and the question never appears.
          if (CountryCustomization.offersCoordinatorRole(
              _countryController.text.trim())) ...[
            const SizedBox(height: 24),
            Text(
              strings.roleQuestion,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRoleOption(
              value: UserRole.teacher,
              title: strings.roleTeacher,
              help: strings.roleTeacherHelp,
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 8),
            _buildRoleOption(
              value: UserRole.coordinator,
              title: strings.roleCoordinator,
              help: strings.roleCoordinatorHelp,
              icon: Icons.supervisor_account_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required String value,
    required String title,
    required String help,
    required IconData icon,
  }) {
    final selected = _selectedRole == value;
    final primary = Theme.of(context).primaryColor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? primary : Colors.grey, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    help,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    final strings = AppStrings.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _detailsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.regStepDetailsTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _firstNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: strings.firstName,
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return strings.enterFirstName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: strings.lastName,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return strings.enterLastName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _schoolController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: strings.schoolName,
                prefixIcon: const Icon(Icons.school),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return strings.enterSchoolName;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStep(BuildContext context) {
    final strings = AppStrings.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _accountFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.regStepAccountTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: strings.username,
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return strings.enterUsername;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: strings.emailOptional,
                prefixIcon: const Icon(Icons.email),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty && !value.contains('@')) {
                  return strings.enterEmail;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: strings.password,
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  tooltip: AppStrings.of(context).togglePasswordVisibility,
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return strings.enterPassword;
                }
                if (value.length < 8) {
                  return strings.passwordMinLength;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButtons(BuildContext context) {
    final strings = AppStrings.of(context);
    final isLastStep = _currentStep == _totalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _back,
                child: Text(strings.back),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: isLastStep
                ? Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      return ElevatedButton(
                        onPressed: auth.isLoading ? null : _register,
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(strings.register),
                      );
                    },
                  )
                : ElevatedButton(
                    onPressed: _next,
                    child: Text(strings.next),
                  ),
          ),
        ],
      ),
    );
  }
}
