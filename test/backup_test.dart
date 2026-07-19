import 'dart:convert';

import 'package:bumpbuddy/models.dart';
import 'package:bumpbuddy/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup export/import round-trip preserves all data', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    await store.saveProfile(PregnancyProfile(
      type: PregnancyType.twins,
      chorionicity: Chorionicity.dcda,
      edd: DateTime(2026, 8, 17),
      lmp: DateTime(2025, 11, 10),
      babies: [Baby(label: 'A', nickname: 'guchi'), Baby(label: 'B')],
    ));
    await store.upsertMedicine(
        Medicine(id: 'm1', name: 'Iron', slots: ['Morning', 'Night']));
    await store.upsertSymptom(SymptomEntry(
        id: 's1', date: DateTime(2026, 7, 1), symptom: 'Heartburn'));
    await store.addWeight(
        WeightEntry(id: 'w1', date: DateTime(2026, 7, 1), kg: 70));
    await store.addBp(BpEntry(
        id: 'b1',
        dateTime: DateTime(2026, 7, 19, 9),
        systolic: 150,
        diastolic: 95));
    await store.upsertContraction(Contraction(
        id: 'c1', start: DateTime(2026, 7, 19, 22), durationSec: 62));
    await store.upsertRecord(RecordItem(
      id: 'r1',
      date: DateTime(2026, 7, 19),
      category: RecordCategory.ultrasound,
      title: 'Growth scan',
      aiJson: '{"babies":[]}',
      attachments: [
        const RecordAttachment(fileName: 'p1.jpg', filePath: '/x/p1.jpg'),
        const RecordAttachment(fileName: 'p2.jpg', filePath: '/x/p2.jpg'),
      ],
    ));
    await store.setWaterToday(7);
    await store.setKickReminder(false);

    // Serialize like the export share does, then restore into a FRESH store.
    final json = jsonEncode(store.exportAll());

    SharedPreferences.setMockInitialValues({});
    final restored = AppStore();
    await restored.load();
    await restored.importAll(jsonDecode(json) as Map<String, dynamic>);

    expect(restored.profile?.isTwins, true);
    expect(restored.profile?.babies.first.displayName, 'guchi');
    expect(restored.medicines.single.slots, ['Morning', 'Night']);
    expect(restored.symptoms.single.symptom, 'Heartburn');
    expect(restored.weights.single.kg, 70);
    expect(restored.bpEntries.single.isHigh, true);
    expect(restored.contractions.single.durationSec, 62);
    expect(restored.records.single.attachments.length, 2);
    expect(restored.records.single.aiJson, '{"babies":[]}');
    expect(restored.waterToday(), 7);
    expect(restored.kickReminderEnabled, false);
    // Hospital bag was seeded on profile save and must survive.
    expect(restored.bagItems, isNotEmpty);
  });

  test('import rejects non-BumpBuddy files', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    expect(
      () => store.importAll({'app': 'SomethingElse'}),
      throwsA(isA<FormatException>()),
    );
  });
}
