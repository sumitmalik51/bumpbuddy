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

class RecordItem {
  final String id;
  DateTime date;
  RecordCategory category;
  String title;
  String notes;
  String fileName; // attachment name; binary storage lands with the mobile build

  RecordItem({
    required this.id,
    required this.date,
    required this.category,
    required this.title,
    this.notes = '',
    this.fileName = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category.name,
        'title': title,
        'notes': notes,
        'fileName': fileName,
      };

  factory RecordItem.fromJson(Map<String, dynamic> j) => RecordItem(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        category: RecordCategory.values.byName(j['category'] as String),
        title: j['title'] as String,
        notes: (j['notes'] ?? '') as String,
        fileName: (j['fileName'] ?? '') as String,
      );
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
