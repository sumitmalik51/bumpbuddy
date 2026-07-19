import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'attachments.dart';
import 'models.dart';
import 'notification_service.dart';

/// Local-first app store. Everything is JSON in shared_preferences behind
/// this single ChangeNotifier, so the storage engine can be swapped for
/// SQLite/drift later without touching the UI.
class AppStore extends ChangeNotifier {
  static const _kProfile = 'profile';
  static const _kSymptoms = 'symptoms';
  static const _kMedicines = 'medicines';
  static const _kAppointments = 'appointments';
  static const _kRecords = 'records';
  static const _kWeights = 'weights';
  static const _kBag = 'bag';
  static const _kWater = 'water'; // map yyyy-mm-dd -> glasses
  static const _kMedsTaken = 'medsTaken'; // map yyyy-mm-dd -> ["medId|slot"]
  static const _kKicks = 'kickSessions';

  SharedPreferences? _prefs;
  bool loaded = false;

  PregnancyProfile? profile;
  List<SymptomEntry> symptoms = [];
  List<Medicine> medicines = [];
  List<Appointment> appointments = [];
  List<RecordItem> records = [];
  List<WeightEntry> weights = [];
  List<ChecklistItem> bagItems = [];
  List<KickSession> kickSessions = [];
  Map<String, int> water = {};
  Map<String, List<String>> medsTaken = {};

  int _idCounter = 0;
  String newId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;

    final profileJson = p.getString(_kProfile);
    if (profileJson != null) {
      profile = PregnancyProfile.fromJson(
          jsonDecode(profileJson) as Map<String, dynamic>);
    }
    symptoms = _readList(_kSymptoms, SymptomEntry.fromJson);
    medicines = _readList(_kMedicines, Medicine.fromJson);
    appointments = _readList(_kAppointments, Appointment.fromJson);
    records = _readList(_kRecords, RecordItem.fromJson);
    weights = _readList(_kWeights, WeightEntry.fromJson);
    bagItems = _readList(_kBag, ChecklistItem.fromJson);
    kickSessions = _readList(_kKicks, KickSession.fromJson);
    water = ((jsonDecode(p.getString(_kWater) ?? '{}')) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
    medsTaken =
        ((jsonDecode(p.getString(_kMedsTaken) ?? '{}')) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as List).cast<String>()));

    loaded = true;
    notifyListeners();
  }

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs!.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeList(String key, List<dynamic> items) async {
    await _prefs!
        .setString(key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  // ---- Profile ----

  Future<void> saveProfile(PregnancyProfile p, {bool reseedBag = false}) async {
    final isNew = profile == null;
    profile = p;
    await _prefs!.setString(_kProfile, jsonEncode(p.toJson()));
    if (isNew || bagItems.isEmpty || reseedBag) {
      _seedHospitalBag(p);
      await _writeList(_kBag, bagItems);
    }
    notifyListeners();
  }

  Future<void> resetAll() async {
    await _prefs!.clear();
    profile = null;
    symptoms = [];
    medicines = [];
    appointments = [];
    records = [];
    weights = [];
    bagItems = [];
    water = {};
    medsTaken = {};
    notifyListeners();
  }

  // ---- Symptoms ----

  Future<void> upsertSymptom(SymptomEntry e) async {
    final i = symptoms.indexWhere((s) => s.id == e.id);
    if (i >= 0) {
      symptoms[i] = e;
    } else {
      symptoms.add(e);
    }
    symptoms.sort((a, b) => b.date.compareTo(a.date));
    await _writeList(_kSymptoms, symptoms);
    notifyListeners();
  }

  Future<void> deleteSymptom(String id) async {
    symptoms.removeWhere((s) => s.id == id);
    await _writeList(_kSymptoms, symptoms);
    notifyListeners();
  }

  // ---- Medicines ----

  Future<void> upsertMedicine(Medicine m) async {
    final i = medicines.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      medicines[i] = m;
    } else {
      medicines.add(m);
    }
    await _writeList(_kMedicines, medicines);
    await NotificationService.instance.syncMedicines(medicines);
    notifyListeners();
  }

  Future<void> deleteMedicine(String id) async {
    medicines.removeWhere((m) => m.id == id);
    await _writeList(_kMedicines, medicines);
    await NotificationService.instance.syncMedicines(medicines);
    notifyListeners();
  }

  bool isMedTaken(DateTime day, String medId, String slot) =>
      (medsTaken[dayKey(day)] ?? const []).contains('$medId|$slot');

  Future<void> toggleMedTaken(DateTime day, String medId, String slot) async {
    final key = dayKey(day);
    final list = List<String>.from(medsTaken[key] ?? const []);
    final token = '$medId|$slot';
    if (list.contains(token)) {
      list.remove(token);
    } else {
      list.add(token);
    }
    medsTaken[key] = list;
    await _prefs!.setString(_kMedsTaken, jsonEncode(medsTaken));
    notifyListeners();
  }

  // ---- Appointments ----

  Future<void> upsertAppointment(Appointment a) async {
    final i = appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      appointments[i] = a;
    } else {
      appointments.add(a);
    }
    appointments.sort((x, y) => x.dateTime.compareTo(y.dateTime));
    await _writeList(_kAppointments, appointments);
    await NotificationService.instance.syncAppointments(appointments);
    notifyListeners();
  }

  Future<void> deleteAppointment(String id) async {
    appointments.removeWhere((a) => a.id == id);
    await _writeList(_kAppointments, appointments);
    await NotificationService.instance.syncAppointments(appointments);
    notifyListeners();
  }

  Appointment? get nextAppointment {
    final now = DateTime.now();
    for (final a in appointments) {
      if (!a.done && a.dateTime.isAfter(now.subtract(const Duration(hours: 12)))) {
        return a;
      }
    }
    return null;
  }

  // ---- Records ----

  Future<void> upsertRecord(RecordItem r) async {
    final i = records.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      records[i] = r;
    } else {
      records.add(r);
    }
    records.sort((x, y) => y.date.compareTo(x.date));
    await _writeList(_kRecords, records);
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    final i = records.indexWhere((r) => r.id == id);
    if (i >= 0) {
      for (final a in records[i].attachments) {
        await Attachments.delete(a.filePath);
      }
      records.removeAt(i);
    }
    await _writeList(_kRecords, records);
    notifyListeners();
  }

  // ---- Weight ----

  Future<void> addWeight(WeightEntry w) async {
    weights.add(w);
    weights.sort((a, b) => a.date.compareTo(b.date));
    await _writeList(_kWeights, weights);
    notifyListeners();
  }

  Future<void> deleteWeight(String id) async {
    weights.removeWhere((w) => w.id == id);
    await _writeList(_kWeights, weights);
    notifyListeners();
  }

  // ---- Water ----

  int waterToday() => water[dayKey(DateTime.now())] ?? 0;

  Future<void> setWaterToday(int glasses) async {
    water[dayKey(DateTime.now())] = glasses.clamp(0, 30);
    await _prefs!.setString(_kWater, jsonEncode(water));
    notifyListeners();
  }

  // ---- Kick counter ----

  Future<void> upsertKickSession(KickSession s) async {
    final i = kickSessions.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      kickSessions[i] = s;
    } else {
      kickSessions.add(s);
    }
    kickSessions.sort((a, b) => b.start.compareTo(a.start));
    await _writeList(_kKicks, kickSessions);
    notifyListeners();
  }

  Future<void> deleteKickSession(String id) async {
    kickSessions.removeWhere((s) => s.id == id);
    await _writeList(_kKicks, kickSessions);
    notifyListeners();
  }

  // ---- Hospital bag ----

  Future<void> toggleBagItem(String id) async {
    final i = bagItems.indexWhere((b) => b.id == id);
    if (i >= 0) {
      bagItems[i].checked = !bagItems[i].checked;
      await _writeList(_kBag, bagItems);
      notifyListeners();
    }
  }

  Future<void> addBagItem(String listId, String text) async {
    bagItems.add(ChecklistItem(id: newId(), listId: listId, text: text));
    await _writeList(_kBag, bagItems);
    notifyListeners();
  }

  Future<void> deleteBagItem(String id) async {
    bagItems.removeWhere((b) => b.id == id);
    await _writeList(_kBag, bagItems);
    notifyListeners();
  }

  void _seedHospitalBag(PregnancyProfile p) {
    final twins = p.isTwins;
    bagItems = [];
    void add(String listId, List<String> items) {
      for (final t in items) {
        bagItems.add(ChecklistItem(id: newId(), listId: listId, text: t));
      }
    }

    add('documents', [
      'Hospital registration file & ID proof',
      'Insurance papers / TPA card',
      'All scan reports & blood reports (or this app!)',
      'Doctor\'s admission note / birth plan',
    ]);

    add('mom', [
      'Comfortable front-open nighties (${twins ? '4–5' : '3–4'})',
      'Maternity pads (2 packs)',
      'Nursing bras (2–3)',
      'Toiletries & lip balm',
      'Slippers with grip',
      'Phone charger (long cable)',
      'Snacks & electrolyte drink',
      'Going-home outfit (loose)',
      if (twins) 'Extra clothes — twin stays are often a little longer',
      if (twins) 'Twin feeding pillow (if using)',
    ]);

    add('babies', [
      if (twins) ...[
        'Onesies with mittens & caps — 6–8 (two babies!)',
        'Swaddle wraps × 4',
        'Newborn + preemie-size diapers (twins often arrive small & early)',
        'Wipes × 2 packs',
        'Soft blankets × 2',
        'TWO car seats installed',
      ] else ...[
        'Onesies with mittens & caps — 3–4',
        'Swaddle wraps × 2',
        'Newborn diapers (1 pack)',
        'Wipes (1 pack)',
        'Soft blanket',
        'Car seat installed',
      ],
    ]);

    add('partner', [
      'Change of clothes',
      'Snacks & water',
      'Power bank',
      'List of people to update',
      if (twins) 'Backup help plan for first nights home (two babies = four hands)',
    ]);
  }
}
