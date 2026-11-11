/// Models for Forms & Polls (`/forms`). Contract: docs/FORMS_DOCS.md.
library;

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);

bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v?.toString().toLowerCase() == 'true';

String _str(dynamic v) => v?.toString() ?? '';

String? _strOrNull(dynamic v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty || s == 'null' ? null : s;
}

List<int> _intList(dynamic v) {
  if (v is! List) return const [];
  final out = <int>[];
  for (final x in v) {
    final n = x is int ? x : int.tryParse(x.toString());
    if (n != null && n >= 0) out.add(n); // floor 0 (Ground) is a real id
  }
  return out;
}

const Duration _ist = Duration(hours: 5, minutes: 30);

/// Parses a forms timestamp to UTC.
///
/// The backend stores and returns IST without a zone (`2026-11-11 18:00:00`);
/// those are read as IST. Strings with `Z` or an offset are honoured as-is.
DateTime? parseFormTime(dynamic v) {
  final s = _strOrNull(v);
  if (s == null) return null;
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
  if (hasZone) return DateTime.tryParse(s)?.toUtc();
  final naive = DateTime.tryParse('${s.replaceFirst(' ', 'T')}Z');
  return naive?.subtract(_ist);
}

/// The backend accepts ISO-8601 with a zone and converts it to IST.
String formTimeToJson(DateTime t) => t.toUtc().toIso8601String();

enum FormKind { poll, form }

FormKind _kind(dynamic v) => v?.toString().toLowerCase() == 'poll' ? FormKind.poll : FormKind.form;

enum FormFieldType { poll, radio, checkbox, boolean, rating, select, text, textarea, number }

extension FormFieldTypeX on FormFieldType {
  String get apiName => name;

  /// Types whose answers come from [FormFieldDef.options].
  bool get hasOptions =>
      this == FormFieldType.poll ||
      this == FormFieldType.radio ||
      this == FormFieldType.checkbox ||
      this == FormFieldType.select;

  /// Minimum options the backend accepts: 2 for poll/radio, 1 for checkbox/select.
  int get minOptions => (this == FormFieldType.poll || this == FormFieldType.radio)
      ? 2
      : (hasOptions ? 1 : 0);

  String get label => switch (this) {
        FormFieldType.poll => 'Poll (one choice)',
        FormFieldType.radio => 'Single choice',
        FormFieldType.checkbox => 'Multiple choice',
        FormFieldType.boolean => 'Yes / No',
        FormFieldType.rating => 'Rating 1–5',
        FormFieldType.select => 'Dropdown',
        FormFieldType.text => 'Short text',
        FormFieldType.textarea => 'Long text',
        FormFieldType.number => 'Number',
      };
}

FormFieldType fieldTypeOf(dynamic v) {
  final s = v?.toString().toLowerCase();
  for (final t in FormFieldType.values) {
    if (t.name == s) return t;
  }
  return FormFieldType.text;
}

/// One question.
class FormFieldDef {
  final String? id;
  final String? key;
  final String label;
  final FormFieldType type;
  final bool required;
  final List<String> options;

  const FormFieldDef({
    this.id,
    this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
  });

  /// The key of this field inside `answers`: `id ?? key ?? label`.
  String get answerKey => id ?? key ?? label;

  factory FormFieldDef.fromJson(Map<String, dynamic> json) => FormFieldDef(
        id: _strOrNull(json['id']),
        key: _strOrNull(json['key']),
        label: _str(json['label']).trim(),
        type: fieldTypeOf(json['type']),
        required: _bool(json['required']),
        options: json['options'] is List
            ? [for (final o in json['options'] as List) o.toString()]
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'id': ?id,
        if (id == null) 'key': ?key,
        'label': label,
        'type': type.apiName,
        'required': required,
        if (type.hasOptions) 'options': options,
      };
}

List<FormFieldDef> _fields(dynamic v) {
  if (v is! List) return const [];
  return [
    for (final f in v.whereType<Map>()) FormFieldDef.fromJson(Map<String, dynamic>.from(f)),
  ];
}

/// Who a form targets. `students` and `floors` from the API are the same as
/// [selected] (a union of picked students, floors and tags).
enum FormAudience { all, current, alumni, selected }

FormAudience audienceOf(dynamic v) => switch (v?.toString().toLowerCase()) {
      'all' => FormAudience.all,
      'current' => FormAudience.current,
      'alumni' => FormAudience.alumni,
      'selected' || 'students' || 'floors' => FormAudience.selected,
      _ => FormAudience.all,
    };

extension FormAudienceX on FormAudience {
  String get label => switch (this) {
        FormAudience.all => 'Everyone',
        FormAudience.current => 'Current residents',
        FormAudience.alumni => 'Alumni',
        FormAudience.selected => 'Selected',
      };
}

enum FormStatus { active, disabled, upcoming, expired, unknown }

FormStatus _status(dynamic v) => switch (v?.toString().toLowerCase()) {
      'active' => FormStatus.active,
      'disabled' => FormStatus.disabled,
      'upcoming' => FormStatus.upcoming,
      'expired' => FormStatus.expired,
      _ => FormStatus.unknown,
    };

/// A form or poll as an admin sees it (`GET /forms`, `GET /forms/:id`).
class HostelForm {
  final int id;
  final String title;
  final String? description;
  final FormKind kind;
  final List<FormFieldDef> fields;
  final FormAudience audience;
  final List<int> targetStudentIds;
  final List<int> targetFloors;
  final List<int> targetTags;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isActive;
  final bool isMandatory;
  final int totalTargeted;
  final int totalViewed;
  final int totalResponded;
  final int seenNotAnswered;
  final FormStatus status;
  final DateTime? createdAt;

  const HostelForm({
    required this.id,
    required this.title,
    this.description,
    this.kind = FormKind.form,
    this.fields = const [],
    this.audience = FormAudience.all,
    this.targetStudentIds = const [],
    this.targetFloors = const [],
    this.targetTags = const [],
    this.startTime,
    this.endTime,
    this.isActive = true,
    this.isMandatory = false,
    this.totalTargeted = 0,
    this.totalViewed = 0,
    this.totalResponded = 0,
    this.seenNotAnswered = 0,
    this.status = FormStatus.unknown,
    this.createdAt,
  });

  HostelForm copyWith({bool? isActive, FormStatus? status}) => HostelForm(
        id: id,
        title: title,
        description: description,
        kind: kind,
        fields: fields,
        audience: audience,
        targetStudentIds: targetStudentIds,
        targetFloors: targetFloors,
        targetTags: targetTags,
        startTime: startTime,
        endTime: endTime,
        isActive: isActive ?? this.isActive,
        isMandatory: isMandatory,
        totalTargeted: totalTargeted,
        totalViewed: totalViewed,
        totalResponded: totalResponded,
        seenNotAnswered: seenNotAnswered,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  factory HostelForm.fromJson(Map<String, dynamic> json) => HostelForm(
        id: _int(json['id']),
        title: _str(json['title']),
        description: _strOrNull(json['description']),
        kind: _kind(json['form_type']),
        fields: _fields(json['fields']),
        audience: audienceOf(json['target_audience']),
        targetStudentIds: _intList(json['target_student_ids']),
        targetFloors: _intList(json['target_floors']),
        targetTags: _intList(json['target_tags']),
        startTime: parseFormTime(json['start_time']),
        endTime: parseFormTime(json['end_time']),
        isActive: _bool(json['is_active']),
        isMandatory: _bool(json['is_mandatory']),
        totalTargeted: _int(json['total_targeted']),
        totalViewed: _int(json['total_viewed']),
        totalResponded: _int(json['total_responded']),
        seenNotAnswered: _int(json['seen_not_answered']),
        status: _status(json['status']),
        createdAt: parseFormTime(json['created_at']),
      );
}

/// A student's submitted answers.
class FormResponse {
  final DateTime? submittedAt;
  final Map<String, dynamic> answers;

  const FormResponse({this.submittedAt, this.answers = const {}});

  static FormResponse? fromJson(dynamic json) {
    if (json is! Map) return null;
    final answers = json['answers'];
    return FormResponse(
      submittedAt: parseFormTime(json['submitted_at']),
      answers: answers is Map ? Map<String, dynamic>.from(answers) : const {},
    );
  }
}

/// An open form or poll as a student sees it (`GET /forms/student/active`).
class StudentForm {
  final int id;
  final String title;
  final String? description;
  final FormKind kind;
  final List<FormFieldDef> fields;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isMandatory;
  final bool hasViewed;
  final bool hasSubmitted;
  final FormResponse? myResponse;

  const StudentForm({
    required this.id,
    required this.title,
    this.description,
    this.kind = FormKind.form,
    this.fields = const [],
    this.startTime,
    this.endTime,
    this.isMandatory = false,
    this.hasViewed = false,
    this.hasSubmitted = false,
    this.myResponse,
  });

  StudentForm copyWith({bool? hasViewed, bool? hasSubmitted, FormResponse? myResponse}) => StudentForm(
        id: id,
        title: title,
        description: description,
        kind: kind,
        fields: fields,
        startTime: startTime,
        endTime: endTime,
        isMandatory: isMandatory,
        hasViewed: hasViewed ?? this.hasViewed,
        hasSubmitted: hasSubmitted ?? this.hasSubmitted,
        myResponse: myResponse ?? this.myResponse,
      );

  factory StudentForm.fromJson(Map<String, dynamic> json) => StudentForm(
        id: _int(json['id']),
        title: _str(json['title']),
        description: _strOrNull(json['description']),
        kind: _kind(json['form_type']),
        fields: _fields(json['fields']),
        startTime: parseFormTime(json['start_time']),
        endTime: parseFormTime(json['end_time']),
        isMandatory: _bool(json['is_mandatory']),
        hasViewed: _bool(json['has_viewed']),
        hasSubmitted: _bool(json['has_submitted']),
        myResponse: FormResponse.fromJson(json['my_response']),
      );
}

/// One option's share in a choice question.
class OptionCount {
  final String option;
  final int count;
  final int percentage;

  const OptionCount(this.option, this.count, this.percentage);
}

/// Results for one question (`field_analytics`).
class FieldAnalytics {
  final String fieldId;
  final String label;
  final FormFieldType type;
  final int totalAnswered;
  final List<OptionCount> breakdown;

  const FieldAnalytics({
    required this.fieldId,
    required this.label,
    required this.type,
    required this.totalAnswered,
    this.breakdown = const [],
  });

  factory FieldAnalytics.fromJson(String key, Map<String, dynamic> json) => FieldAnalytics(
        fieldId: _strOrNull(json['field_id']) ?? key,
        label: _str(json['label']),
        type: fieldTypeOf(json['type']),
        totalAnswered: _int(json['total_answered']),
        breakdown: json['breakdown'] is List
            ? [
                for (final b in (json['breakdown'] as List).whereType<Map>())
                  OptionCount(_str(b['option']), _int(b['count']), _int(b['percentage'])),
              ]
            : const [],
      );
}

/// A student in an analytics list (responded / seen / not responded).
/// The backend shape isn't fixed, so common name/room/time keys are read.
class AnalyticsPerson {
  final int? studentId;
  final String name;
  final String room;
  final DateTime? at;
  final Map<String, dynamic> answers;

  const AnalyticsPerson({
    this.studentId,
    required this.name,
    this.room = '',
    this.at,
    this.answers = const {},
  });

  factory AnalyticsPerson.fromJson(Map<String, dynamic> json) {
    final answers = json['answers'];
    final id = _int(json['student_id'] ?? json['id']);
    return AnalyticsPerson(
      studentId: id > 0 ? id : null,
      name: _strOrNull(json['name'] ?? json['student_name'] ?? json['full_name']) ?? 'Student',
      room: _str(json['room'] ?? json['room_number']),
      at: parseFormTime(json['submitted_at'] ?? json['viewed_at'] ?? json['created_at']),
      answers: answers is Map ? Map<String, dynamic>.from(answers) : const {},
    );
  }
}

List<AnalyticsPerson> _people(dynamic v) {
  if (v is! List) return const [];
  return [
    for (final p in v.whereType<Map>()) AnalyticsPerson.fromJson(Map<String, dynamic>.from(p)),
  ];
}

/// `GET /forms/:id/analytics`.
class FormAnalytics {
  final HostelForm form;
  final int totalTargeted;
  final int totalViewed;
  final int totalResponded;
  final int seenNotAnswered;
  final int neverSeen;
  final int responseRate;
  final List<FieldAnalytics> fields;
  final List<AnalyticsPerson> responses;
  final List<AnalyticsPerson> seenNotAnsweredList;
  final List<AnalyticsPerson> notResponded;

  const FormAnalytics({
    required this.form,
    this.totalTargeted = 0,
    this.totalViewed = 0,
    this.totalResponded = 0,
    this.seenNotAnswered = 0,
    this.neverSeen = 0,
    this.responseRate = 0,
    this.fields = const [],
    this.responses = const [],
    this.seenNotAnsweredList = const [],
    this.notResponded = const [],
  });

  factory FormAnalytics.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : const <String, dynamic>{};
    final form = json['form'] is Map
        ? HostelForm.fromJson(Map<String, dynamic>.from(json['form'] as Map))
        : const HostelForm(id: 0, title: '');
    final raw = json['field_analytics'];
    final fields = <FieldAnalytics>[];
    if (raw is Map) {
      // Keep the form's question order.
      final byKey = {
        for (final e in raw.entries)
          if (e.value is Map) e.key.toString(): FieldAnalytics.fromJson(e.key.toString(), Map<String, dynamic>.from(e.value as Map)),
      };
      for (final f in form.fields) {
        final a = byKey.remove(f.answerKey);
        if (a != null) fields.add(a);
      }
      fields.addAll(byKey.values);
    }
    return FormAnalytics(
      form: form,
      totalTargeted: _int(summary['total_targeted']),
      totalViewed: _int(summary['total_viewed']),
      totalResponded: _int(summary['total_responded']),
      seenNotAnswered: _int(summary['seen_not_answered']),
      neverSeen: _int(summary['never_seen']),
      responseRate: _int(summary['response_rate']),
      fields: fields,
      responses: _people(json['responses']),
      seenNotAnsweredList: _people(json['seen_not_answered']),
      notResponded: _people(json['not_responded']),
    );
  }
}
