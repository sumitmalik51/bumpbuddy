// Boots the real app widget tree with a seeded store (singleton and twins)
// and fails on ANY uncaught framework exception — catches blank-screen
// regressions that unit tests can't see.

import 'dart:convert';

import 'package:bumpbuddy/main.dart';
import 'package:bumpbuddy/models.dart';
import 'package:bumpbuddy/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _storeWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = AppStore();
  await store.load();
  return store;
}

String _profileJson({required bool twins}) => jsonEncode(PregnancyProfile(
      type: twins ? PregnancyType.twins : PregnancyType.singleton,
      chorionicity: twins ? Chorionicity.dcda : null,
      edd: DateTime.now().add(const Duration(days: 60)),
      lmp: DateTime.now().subtract(const Duration(days: 220)),
      babies: twins
          ? [Baby(label: 'A', nickname: 'A1'), Baby(label: 'B')]
          : [Baby(label: 'A')],
    ).toJson());

Future<void> _pumpApp(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(BumpBuddyApp(store: store));
  // Fixed pumps (not pumpAndSettle — the app has infinite subtle
  // animations like the pulsing hearts).
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final e = tester.takeException();
    expect(e, isNull, reason: 'frame $i threw: $e');
  }
}

void main() {
  testWidgets('singleton dashboard boots without exceptions', (tester) async {
    final store = await _storeWith({'profile': _profileJson(twins: false)});
    await _pumpApp(tester, store);
    expect(find.text('Your baby'), findsOneWidget);
    expect(find.text('Growth'), findsWidgets);
  });

  testWidgets('twins dashboard boots without exceptions', (tester) async {
    final store = await _storeWith({'profile': _profileJson(twins: true)});
    await _pumpApp(tester, store);
    expect(find.text('Your twins'), findsOneWidget);
  });

  testWidgets('all five tabs build without exceptions (twins)',
      (tester) async {
    final store = await _storeWith({'profile': _profileJson(twins: true)});
    await _pumpApp(tester, store);
    for (final tab in ['Timeline', 'Journal', 'Records', 'More']) {
      await tester.tap(find.text(tab).last);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final e = tester.takeException();
        expect(e, isNull, reason: 'tab $tab frame $i threw: $e');
      }
    }
  });

  testWidgets('setup screen boots when no profile exists', (tester) async {
    final store = await _storeWith({});
    await _pumpApp(tester, store);
    expect(find.text('Welcome to BumpBuddy'), findsOneWidget);
  });
}
