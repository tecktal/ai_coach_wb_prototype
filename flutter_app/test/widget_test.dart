// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_coach/data/providers/connectivity_provider.dart';
import 'package:ai_coach/data/providers/recording_provider.dart';
import 'package:ai_coach/data/providers/locale_provider.dart';
import 'package:ai_coach/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final connectivity = ConnectivityProvider();
    final recording = RecordingProvider();
    final locale = LocaleProvider();
    await tester.pumpWidget(MyApp(
      connectivityProvider: connectivity,
      recordingProvider: recording,
      localeProvider: locale,
    ));
    // Just verify the app renders without crashing
    expect(find.byType(MyApp), findsOneWidget);
  });
}
