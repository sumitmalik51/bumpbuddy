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
  static const _kBp = 'bpEntries';
  static const _kContractions = 'contractions';
  static const _kKickReminder = 'kickReminderEnabled';
  static const _kChat = 'chatMessages';

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
  List<BpEntry> bpEntries = [];
  List<Contraction> contractions = [];
  bool kickReminderEnabled = true;
  List<ChatMessage> chatMessages = [];
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
    bpEntries = _readList(_kBp, BpEntry.fromJson);
    contractions = _readList(_kContractions, Contraction.fromJson);
    kickReminderEnabled = p.getBool(_kKickReminder) ?? true;
    chatMessages = _readList(_kChat, ChatMessage.fromJson);
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

  // ---- Blood pressure ----

  Future<void> addBp(BpEntry e) async {
    bpEntries.add(e);
    bpEntries.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    await _writeList(_kBp, bpEntries);
    notifyListeners();
  }

  Future<void> deleteBp(String id) async {
    bpEntries.removeWhere((e) => e.id == id);
    await _writeList(_kBp, bpEntries);
    notifyListeners();
  }

  // ---- Contractions ----

  Future<void> upsertContraction(Contraction c) async {
    final i = contractions.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      contractions[i] = c;
    } else {
      contractions.add(c);
    }
    contractions.sort((a, b) => b.start.compareTo(a.start));
    // Keep the log bounded — labour monitoring only needs recent history.
    if (contractions.length > 200) {
      contractions = contractions.take(200).toList();
    }
    await _writeList(_kContractions, contractions);
    notifyListeners();
  }

  Future<void> deleteContraction(String id) async {
    contractions.removeWhere((c) => c.id == id);
    await _writeList(_kContractions, contractions);
    notifyListeners();
  }

  Future<void> clearContractions() async {
    contractions = [];
    await _writeList(_kContractions, contractions);
    notifyListeners();
  }

  // ---- Chat ----

  Future<void> addChatMessage(ChatMessage m) async {
    chatMessages.add(m);
    if (chatMessages.length > 200) {
      chatMessages = chatMessages.sublist(chatMessages.length - 200);
    }
    await _writeList(_kChat, chatMessages);
    notifyListeners();
  }

  Future<void> clearChat() async {
    chatMessages = [];
    await _writeList(_kChat, chatMessages);
    notifyListeners();
  }

  // ---- Kick reminder preference ----

  Future<void> setKickReminder(bool enabled) async {
    kickReminderEnabled = enabled;
    await _prefs!.setBool(_kKickReminder, enabled);
    notifyListeners();
  }

  // ---- Backup / restore ----

  /// Everything the app knows, as one JSON document.
  Map<String, dynamic> exportAll() => {
        'app': 'BumpBuddy',
        'backupVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'profile': profile?.toJson(),
        'symptoms': symptoms.map((e) => e.toJson()).toList(),
        'medicines': medicines.map((e) => e.toJson()).toList(),
        'appointments': appointments.map((e) => e.toJson()).toList(),
        'records': records.map((e) => e.toJson()).toList(),
        'weights': weights.map((e) => e.toJson()).toList(),
        'bag': bagItems.map((e) => e.toJson()).toList(),
        'kickSessions': kickSessions.map((e) => e.toJson()).toList(),
        'bpEntries': bpEntries.map((e) => e.toJson()).toList(),
        'contractions': contractions.map((e) => e.toJson()).toList(),
        'water': water,
        'medsTaken': medsTaken,
        'kickReminderEnabled': kickReminderEnabled,
      };

  /// Replaces ALL current data with [data] (a previously exported backup).
  /// Attachment files are not part of the backup — only their metadata.
  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['app'] != 'BumpBuddy') {
      throw const FormatException('Not a BumpBuddy backup file.');
    }
    List<T> read<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((data[key] ?? []) as List)
            .map((e) => f((e as Map).cast<String, dynamic>()))
            .toList();

    profile = data['profile'] == null
        ? null
        : PregnancyProfile.fromJson(
            (data['profile'] as Map).cast<String, dynamic>());
    symptoms = read(_kSymptoms, SymptomEntry.fromJson);
    medicines = read(_kMedicines, Medicine.fromJson);
    appointments = read(_kAppointments, Appointment.fromJson);
    records = read(_kRecords, RecordItem.fromJson);
    weights = read(_kWeights, WeightEntry.fromJson);
    bagItems = read(_kBag, ChecklistItem.fromJson);
    kickSessions = read(_kKicks, KickSession.fromJson);
    bpEntries = read(_kBp, BpEntry.fromJson);
    contractions = read(_kContractions, Contraction.fromJson);
    water = ((data['water'] ?? {}) as Map)
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    medsTaken = ((data['medsTaken'] ?? {}) as Map).map(
        (k, v) => MapEntry(k as String, (v as List).cast<String>()));
    kickReminderEnabled = (data['kickReminderEnabled'] ?? true) as bool;

    final p = _prefs!;
    if (profile != null) {
      await p.setString(_kProfile, jsonEncode(profile!.toJson()));
    } else {
      await p.remove(_kProfile);
    }
    await _writeList(_kSymptoms, symptoms);
    await _writeList(_kMedicines, medicines);
    await _writeList(_kAppointments, appointments);
    await _writeList(_kRecords, records);
    await _writeList(_kWeights, weights);
    await _writeList(_kBag, bagItems);
    await _writeList(_kKicks, kickSessions);
    await _writeList(_kBp, bpEntries);
    await _writeList(_kContractions, contractions);
    await p.setString(_kWater, jsonEncode(water));
    await p.setString(_kMedsTaken, jsonEncode(medsTaken));
    await p.setBool(_kKickReminder, kickReminderEnabled);

    await NotificationService.instance.syncMedicines(medicines);
    await NotificationService.instance.syncAppointments(appointments);
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
