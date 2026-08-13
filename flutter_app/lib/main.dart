import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/recording_provider.dart';
import 'data/providers/analysis_provider.dart';
import 'data/providers/chat_provider.dart';
import 'data/providers/coach_script_provider.dart';
import 'data/providers/theme_provider.dart';
import 'data/providers/connectivity_provider.dart';
import 'data/providers/locale_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_strings.dart';
import 'presentation/widgets/country_customization.dart';
import 'core/utils/app_logger.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route Flutter framework errors to the logger so they surface in the
  // in-app log buffer rather than silently causing a black screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };

  // Intercept all debugPrint calls into the in-app log buffer.
  // This lets us copy logs from the device without USB/ADB.
  AppLogger.capture();

  try {
    await NotificationService.init();
  } catch (e) {
    // Notification init failure must never crash the app.
    // Local notifications are non-critical; the app works without them.
    debugPrint('[Startup] NotificationService.init() failed: $e');
  }

  // Start monitoring connectivity before the first frame is drawn so that
  // the offline banner state is correct immediately on launch.
  final connectivityProvider = ConnectivityProvider();
  try {
    await connectivityProvider.init();
  } catch (e) {
    debugPrint('[Startup] ConnectivityProvider.init() failed: $e');
  }

  // RecordingProvider is created here so both main() and MultiProvider share
  // the same instance.
  final recordingProvider = RecordingProvider();
  // NOTE: We intentionally do NOT auto-upload drafts on reconnect.
  // Teachers explicitly choose when to analyse via "Save & Analyse Now"
  // or "Run Analysis" in My Lessons. Auto-uploading violated that intent.

  // Restore persisted language before the first frame.
  final localeProvider = LocaleProvider();
  await localeProvider.init();

  // Notifications are raised from a background poll with no BuildContext, so
  // the provider needs the locale directly to localize their text.
  recordingProvider.attachLocaleProvider(localeProvider);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(MyApp(
    connectivityProvider: connectivityProvider,
    recordingProvider: recordingProvider,
    localeProvider: localeProvider,
  ));
}

class MyApp extends StatelessWidget {
  final ConnectivityProvider connectivityProvider;
  final RecordingProvider recordingProvider;
  final LocaleProvider localeProvider;

  const MyApp({
    super.key,
    required this.connectivityProvider,
    required this.recordingProvider,
    required this.localeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Use .value so we keep the already-initialised instances
        ChangeNotifierProvider<ConnectivityProvider>.value(
            value: connectivityProvider),
        ChangeNotifierProvider<LocaleProvider>.value(
            value: localeProvider),
        // Inject localeProvider at creation so _syncLocale() works on login/load.
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider()..attachLocaleProvider(localeProvider)),
        ChangeNotifierProvider<RecordingProvider>.value(
            value: recordingProvider),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CoachScriptProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer3<ThemeProvider, AuthProvider, LocaleProvider>(
        builder: (context, themeProvider, authProvider, locProvider, _) {
          final country = authProvider.user?.country;
          final isCustom = CountryCustomization.isCustomized(country);
          final customColor =
              isCustom ? CountryCustomization.getAccentColor(country) : null;

          return MaterialApp(
            title: 'AI Teaching Coach',
            theme: AppTheme.getLightTheme(customColor),
            darkTheme: AppTheme.getDarkTheme(customColor),
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
            // ── Localisation ───────────────────────────────────────────────
            locale: locProvider.locale,
            supportedLocales: const [
              Locale('en'),
              Locale('pt'),
              Locale('fr'),
              Locale('am'),
              Locale('sw'),
            ],
            localizationsDelegates: const [
              AppStringsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
