enum PregnancyType { singleton, twins }

enum Chorionicity { dcda, mcda, mcma, unknown }

extension ChorionicityInfo on Chorionicity {
  String get shortName => switch (this) {
        Chorionicity.dcda => 'DCDA (Di-Di)',
        Chorionicity.mcda => 'MCDA (Mo-Di)',
        Chorionicity.mcma => 'MCMA (Mo-Mo)',
        Chorionicity.unknown => 'Not sure yet',
      };

  String get friendly => switch (this) {
        Chorionicity.dcda =>
          'Two placentas, two sacs. The most common and lowest-risk twin type.',
        Chorionicity.mcda =>
          'One shared placenta, two sacs. Needs closer monitoring (scans every 2 weeks from week 16).',
        Chorionicity.mcma =>
          'One shared placenta and one shared sac. Rare — your team will monitor very closely.',
        Chorionicity.unknown =>
          'Your doctor determines this on a first-trimester scan. You can set it later in Profile.',
      };
}

class Baby {
  final String label; // 'A' or 'B'
  String nickname;
  Baby({required this.label, this.nickname = ''});

  String get displayName =>
      nickname.trim().isEmpty ? 'Baby $label' : nickname.trim();

  Map<String, dynamic> toJson() => {'label': label, 'nickname': nickname};
  factory Baby.fromJson(Map<String, dynamic> j) =>
      Baby(label: j['label'] as String, nickname: (j['nickname'] ?? '') as String);
}

class PregnancyProfile {
  PregnancyType type;
  Chorionicity? chorionicity; // twins only
  DateTime edd; // always stored; derived from LMP if needed
  DateTime? lmp;
  bool ivf;
  List<Baby> babies;
  String doctorName;
  String hospitalName;
  DateTime createdAt;
  bool delivered; // babies have arrived — pregnancy tracking winds down
  DateTime? deliveredAt;

  PregnancyProfile({
    required this.type,
    this.chorionicity,
    required this.edd,
    this.lmp,
    this.ivf = false,
    required this.babies,
    this.doctorName = '',
    this.hospitalName = '',
    DateTime? createdAt,
    this.delivered = false,
    this.deliveredAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isTwins => type == PregnancyType.twins;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'chorionicity': chorionicity?.name,
        'edd': edd.toIso8601String(),
        'lmp': lmp?.toIso8601String(),
        'ivf': ivf,
        'babies': babies.map((b) => b.toJson()).toList(),
        'doctorName': doctorName,
        'hospitalName': hospitalName,
        'createdAt': createdAt.toIso8601String(),
        'delivered': delivered,
        'deliveredAt': deliveredAt?.toIso8601String(),
      };

  factory PregnancyProfile.fromJson(Map<String, dynamic> j) => PregnancyProfile(
        type: PregnancyType.values.byName(j['type'] as String),
        chorionicity: j['chorionicity'] == null
            ? null
            : Chorionicity.values.byName(j['chorionicity'] as String),
        edd: DateTime.parse(j['edd'] as String),
        lmp: j['lmp'] == null ? null : DateTime.parse(j['lmp'] as String),
        ivf: (j['ivf'] ?? false) as bool,
        babies: ((j['babies'] ?? []) as List)
            .map((b) => Baby.fromJson(b as Map<String, dynamic>))
            .toList(),
        doctorName: (j['doctorName'] ?? '') as String,
        hospitalName: (j['hospitalName'] ?? '') as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        delivered: (j['delivered'] ?? false) as bool,
        deliveredAt: j['deliveredAt'] == null
            ? null
            : DateTime.parse(j['deliveredAt'] as String),
      );
}

class SymptomEntry {
  final String id;
  DateTime date;
  String symptom;
  int severity; // 1..5
  String duration;
  String medicineTaken;
  bool doctorInformed;
  String notes;

  SymptomEntry({
    required this.id,
    required this.date,
    required this.symptom,
    this.severity = 2,
    this.duration = '',
    this.medicineTaken = '',
    this.doctorInformed = false,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'symptom': symptom,
        'severity': severity,
        'duration': duration,
        'medicineTaken': medicineTaken,
        'doctorInformed': doctorInformed,
        'notes': notes,
      };

  factory SymptomEntry.fromJson(Map<String, dynamic> j) => SymptomEntry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        symptom: j['symptom'] as String,
        severity: (j['severity'] ?? 2) as int,
        duration: (j['duration'] ?? '') as String,
        medicineTaken: (j['medicineTaken'] ?? '') as String,
        doctorInformed: (j['doctorInformed'] ?? false) as bool,
        notes: (j['notes'] ?? '') as String,
      );
}

class Medicine {
  final String id;
  String name;
  String dose;
  List<String> slots; // 'Morning', 'Afternoon', 'Evening', 'Night'
  bool active;
  String notes;

  Medicine({
    required this.id,
    required this.name,
    this.dose = '',
    this.slots = const ['Morning'],
    this.active = true,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'slots': slots,
        'active': active,
        'notes': notes,
      };

  factory Medicine.fromJson(Map<String, dynamic> j) => Medicine(
        id: j['id'] as String,
        name: j['name'] as String,
        dose: (j['dose'] ?? '') as String,
        slots: ((j['slots'] ?? ['Morning']) as List).cast<String>(),
        active: (j['active'] ?? true) as bool,
        notes: (j['notes'] ?? '') as String,
      );
}

enum AppointmentType { doctorVisit, scan, bloodTest, vaccination, classSession, other }

extension AppointmentTypeInfo on AppointmentType {
  String get label => switch (this) {
        AppointmentType.doctorVisit => 'Doctor visit',
        AppointmentType.scan => 'Scan',
        AppointmentType.bloodTest => 'Blood test',
        AppointmentType.vaccination => 'Vaccination',
        AppointmentType.classSession => 'Class',
        AppointmentType.other => 'Other',
      };
}

class Appointment {
  final String id;
  DateTime dateTime;
  String title;
  AppointmentType type;
  String notes;
  bool done;

  Appointment({
    required this.id,
    required this.dateTime,
    required this.title,
    this.type = AppointmentType.doctorVisit,
    this.notes = '',
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'title': title,
        'type': type.name,
        'notes': notes,
        'done': done,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String,
        dateTime: DateTime.parse(j['dateTime'] as String),
        title: j['title'] as String,
        type: AppointmentType.values.byName((j['type'] ?? 'doctorVisit') as String),
        notes: (j['notes'] ?? '') as String,
        done: (j['done'] ?? false) as bool,
      );
}

enum RecordCategory { ultrasound, bloodTest, prescription, vaccination, bill, photo, other }

extension RecordCategoryInfo on RecordCategory {
  String get label => switch (this) {
        RecordCategory.ultrasound => 'Ultrasound',
        RecordCategory.bloodTest => 'Blood test',
        RecordCategory.prescription => 'Prescription',
        RecordCategory.vaccination => 'Vaccination',
        RecordCategory.bill => 'Hospital bill',
        RecordCategory.photo => 'Photo',
        RecordCategory.other => 'Other',
      };
}

class RecordAttachment {
  final String fileName;
  final String filePath; // copy inside the app's documents dir (mobile only)
  const RecordAttachment({required this.fileName, required this.filePath});

  bool get isImage {
    final n = (fileName.isNotEmpty ? fileName : filePath).toLowerCase();
    return n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp');
  }

  Map<String, dynamic> toJson() =>
      {'fileName': fileName, 'filePath': filePath};

  factory RecordAttachment.fromJson(Map<String, dynamic> j) =>
      RecordAttachment(
        fileName: (j['fileName'] ?? '') as String,
        filePath: (j['filePath'] ?? '') as String,
      );
}

class RecordItem {
  final String id;
  DateTime date;
  RecordCategory category;
  String title;
  String notes;
  List<RecordAttachment> attachments; // report pages, in order
  String aiJson; // AI extraction result (scan reader), empty if not run

  RecordItem({
    required this.id,
    required this.date,
    required this.category,
    required this.title,
    this.notes = '',
    List<RecordAttachment>? attachments,
    this.aiJson = '',
  }) : attachments = attachments ?? [];

  bool get hasAttachment => attachments.isNotEmpty;

  List<RecordAttachment> get imageAttachments =>
      attachments.where((a) => a.isImage).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category.name,
        'title': title,
        'notes': notes,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        // Legacy single-attachment fields kept for downgrade safety.
        'fileName': attachments.isEmpty ? '' : attachments.first.fileName,
        'filePath': attachments.isEmpty ? '' : attachments.first.filePath,
        'aiJson': aiJson,
      };

  factory RecordItem.fromJson(Map<String, dynamic> j) {
    var attachments = ((j['attachments'] ?? []) as List)
        .map((a) => RecordAttachment.fromJson(a as Map<String, dynamic>))
        .toList();
    // Migrate pre-multi-photo records.
    final legacyPath = (j['filePath'] ?? '') as String;
    if (attachments.isEmpty && legacyPath.isNotEmpty) {
      attachments = [
        RecordAttachment(
            fileName: (j['fileName'] ?? '') as String, filePath: legacyPath),
      ];
    }
    return RecordItem(
      id: j['id'] as String,
      date: DateTime.parse(j['date'] as String),
      category: RecordCategory.values.byName(j['category'] as String),
      title: j['title'] as String,
      notes: (j['notes'] ?? '') as String,
      attachments: attachments,
      aiJson: (j['aiJson'] ?? '') as String,
    );
  }
}

class WeightEntry {
  final String id;
  DateTime date;
  double kg;

  WeightEntry({required this.id, required this.date, required this.kg});

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date.toIso8601String(), 'kg': kg};

  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        kg: (j['kg'] as num).toDouble(),
      );
}

class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime time;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'role': role, 'text': text, 'time': time.toIso8601String()};

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        role: j['role'] as String,
        text: j['text'] as String,
        time: DateTime.parse(j['time'] as String),
      );
}

class SavedAnswer {
  final String id;
  final String question;
  final String answer;
  final DateTime time;

  SavedAnswer({
    required this.id,
    required this.question,
    required this.answer,
    required this.time,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'question': question, 'answer': answer, 'time': time.toIso8601String()};

  factory SavedAnswer.fromJson(Map<String, dynamic> j) => SavedAnswer(
        id: j['id'] as String,
        question: (j['question'] ?? '') as String,
        answer: (j['answer'] ?? '') as String,
        time: DateTime.parse(j['time'] as String),
      );
}

class BpEntry {
  final String id;
  DateTime dateTime;
  int systolic;
  int diastolic;
  String note;

  BpEntry({
    required this.id,
    required this.dateTime,
    required this.systolic,
    required this.diastolic,
    this.note = '',
  });

  /// 140/90 is the usual threshold doctors watch in pregnancy;
  /// 160/110 warrants same-day contact.
  bool get isHigh => systolic >= 140 || diastolic >= 90;
  bool get isVeryHigh => systolic >= 160 || diastolic >= 110;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'systolic': systolic,
        'diastolic': diastolic,
        'note': note,
      };

  factory BpEntry.fromJson(Map<String, dynamic> j) => BpEntry(
        id: j['id'] as String,
        dateTime: DateTime.parse(j['dateTime'] as String),
        systolic: (j['systolic'] as num).toInt(),
        diastolic: (j['diastolic'] as num).toInt(),
        note: (j['note'] ?? '') as String,
      );
}

class Contraction {
  final String id;
  DateTime start;
  int durationSec; // 0 while running

  Contraction({required this.id, required this.start, this.durationSec = 0});

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start.toIso8601String(),
        'durationSec': durationSec,
      };

  factory Contraction.fromJson(Map<String, dynamic> j) => Contraction(
        id: j['id'] as String,
        start: DateTime.parse(j['start'] as String),
        durationSec: (j['durationSec'] ?? 0) as int,
      );
}

class KickSession {
  final String id;
  final String babyLabel; // 'A' or 'B'
  final DateTime start;
  List<DateTime> kicks;
  bool ended;

  KickSession({
    required this.id,
    required this.babyLabel,
    required this.start,
    List<DateTime>? kicks,
    this.ended = false,
  }) : kicks = kicks ?? [];

  /// Minutes from start to the 10th kick (the "count to 10" metric).
  int? get minutesToTen => kicks.length >= 10
      ? kicks[9].difference(start).inMinutes
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyLabel': babyLabel,
        'start': start.toIso8601String(),
        'kicks': kicks.map((k) => k.toIso8601String()).toList(),
        'ended': ended,
      };

  factory KickSession.fromJson(Map<String, dynamic> j) => KickSession(
        id: j['id'] as String,
        babyLabel: (j['babyLabel'] ?? 'A') as String,
        start: DateTime.parse(j['start'] as String),
        kicks: ((j['kicks'] ?? []) as List)
            .map((k) => DateTime.parse(k as String))
            .toList(),
        ended: (j['ended'] ?? false) as bool,
      );
}

class ChecklistItem {
  final String id;
  final String listId; // 'mom', 'babies', 'documents', 'partner'
  String text;
  bool checked;

  ChecklistItem({
    required this.id,
    required this.listId,
    required this.text,
    this.checked = false,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'listId': listId, 'text': text, 'checked': checked};

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'] as String,
        listId: j['listId'] as String,
        text: j['text'] as String,
        checked: (j['checked'] ?? false) as bool,
      );
}
