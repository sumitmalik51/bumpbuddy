import 'dart:convert';

import 'package:bumpbuddy/main.dart';
import 'package:bumpbuddy/models.dart';
import 'package:bumpbuddy/store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _twinProfile() => jsonEncode(PregnancyProfile(
      type: PregnancyType.twins,
      chorionicity: Chorionicity.dcda,
      edd: DateTime.now().add(const Duration(days: 40)),
      lmp: DateTime.now().subtract(const Duration(days: 240)),
      babies: [Baby(label: 'A'), Baby(label: 'B')],
    ).toJson());

Future<void> _boot(WidgetTester tester, String lang) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({
    'profile': _twinProfile(),
    'languageCode': lang,
  });
  final store = AppStore();
  await store.load();
  await tester.pumpWidget(BumpBuddyApp(store: store));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('English renders English chrome', (tester) async {
    await _boot(tester, 'en');
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Your twins'), findsWidgets);
  });

  testWidgets('Hindi renders Devanagari chrome', (tester) async {
    await _boot(tester, 'hi');
    expect(find.text('होम'), findsWidgets); // nav: Home
    expect(find.text('आपके जुड़वाँ'), findsWidgets); // dashboard: Your twins
    expect(tester.takeException(), isNull);
  });
}
