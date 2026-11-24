/// Field errors keyed like `personal.firstName` or `documents.id_front`.
typedef KycFieldErrors = Map<String, String>;

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

// Date-only strings (yyyy-MM-dd) are read as UTC midnight, like the server's
// ISO timestamps.
DateTime? _date(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v.length == 10 ? '${v}T00:00:00Z' : v);
  return d?.toUtc();
}

int _int(Object? v) => v is num ? v.toInt() : 0;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) =>
    v is List ? [for (final e in v) if (e is Map) parse(_map(e))] : <T>[];

String _ymd(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

class KycPersonal {
  const KycPersonal({
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.nationality,
  });

  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? nationality;

  factory KycPersonal.fromJson(Map<String, dynamic> j) => KycPersonal(
        firstName: _str(j['firstName']),
        lastName: _str(j['lastName']),
        dateOfBirth: _date(j['dateOfBirth']),
        gender: _str(j['gender']),
        nationality: _str(j['nationality']),
      );

  Map<String, dynamic> toJson() => {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (dateOfBirth != null) 'dateOfBirth': _ymd(dateOfBirth!),
        if (gender != null) 'gender': gender,
        if (nationality != null) 'nationality': nationality,
      };
}

class KycAddress {
  const KycAddress({this.line1, this.line2, this.city, this.country});

  final String? line1;
  final String? line2;
  final String? city;
  final String? country;

  factory KycAddress.fromJson(Map<String, dynamic> j) => KycAddress(
        line1: _str(j['line1']),
        line2: _str(j['line2']),
        city: _str(j['city']),
        country: _str(j['country']),
      );

  Map<String, dynamic> toJson() => {
        if (line1 != null) 'line1': line1,
        if (line2 != null) 'line2': line2,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
      };
}

class KycIdentification {
  const KycIdentification({
    this.idType,
    this.idNumberMasked,
    this.newIdNumber,
    this.idExpiry,
  });

  final String? idType;

  /// Display only. Never sent to the server.
  final String? idNumberMasked;

  /// Set only when the user typed a new ID number. The server never returns
  /// the plain number.
  final String? newIdNumber;
  final DateTime? idExpiry;

  factory KycIdentification.fromJson(Map<String, dynamic> j) =>
      KycIdentification(
        idType: _str(j['idType']),
        idNumberMasked: _str(j['idNumberMasked']),
        idExpiry: _date(j['idExpiry']),
      );

  Map<String, dynamic> toJson() => {
        if (idType != null) 'idType': idType,
        if (newIdNumber != null && newIdNumber!.trim().isNotEmpty)
          'idNumber': newIdNumber!.trim(),
        if (idExpiry != null) 'idExpiry': _ymd(idExpiry!),
      };
}

class KycDraft {
  const KycDraft({
    this.personal = const KycPersonal(),
    this.address = const KycAddress(),
    this.identification = const KycIdentification(),
  });

  final KycPersonal personal;
  final KycAddress address;
  final KycIdentification identification;

  factory KycDraft.fromJson(Map<String, dynamic> j) => KycDraft(
        personal: KycPersonal.fromJson(_map(j['personal'])),
        address: KycAddress.fromJson(_map(j['address'])),
        identification: KycIdentification.fromJson(_map(j['identification'])),
      );

  /// Null fields and empty sections are omitted so the server keeps the
  /// values it already has.
  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    final sections = {
      'personal': personal.toJson(),
      'address': address.toJson(),
      'identification': identification.toJson(),
    };
    sections.forEach((k, v) {
      if (v.isNotEmpty) out[k] = v;
    });
    return out;
  }
}

class KycDocumentInfo {
  const KycDocumentInfo({
    required this.id,
    required this.kind,
    required this.mime,
    required this.size,
    this.createdAt,
  });

  final String id;
  final String kind;
  final String mime;
  final int size;
  final DateTime? createdAt;

  factory KycDocumentInfo.fromJson(Map<String, dynamic> j) => KycDocumentInfo(
        id: _str(j['id']) ?? '',
        kind: _str(j['kind']) ?? '',
        mime: _str(j['mime']) ?? '',
        size: _int(j['size']),
        createdAt: _date(j['createdAt']),
      );
}

class KycHistoryEntry {
  const KycHistoryEntry({
    required this.version,
    this.submittedAt,
    required this.decision,
    this.decidedAt,
    this.reason,
  });

  final int version;
  final DateTime? submittedAt;

  /// `pending`, `approved`, `rejected`, `correction_requested` or `expired`,
  /// as sent by the server.
  final String decision;
  final DateTime? decidedAt;
  final String? reason;

  factory KycHistoryEntry.fromJson(Map<String, dynamic> j) => KycHistoryEntry(
        version: _int(j['version']),
        submittedAt: _date(j['submittedAt']),
        decision: _str(j['decision']) ?? '',
        decidedAt: _date(j['decidedAt']),
        reason: _str(j['reason']),
      );
}

class KycStatus {
  const KycStatus({
    required this.launched,
    required this.status,
    required this.underlyingStatus,
    this.deadline,
    this.exemptUntil,
    required this.progress,
    required this.outstanding,
    required this.draft,
    required this.documents,
    required this.history,
    this.rejectionReason,
    this.correctionNotes,
    required this.phone,
  });

  final bool launched;
  final String status;
  final String underlyingStatus;
  final DateTime? deadline;
  final DateTime? exemptUntil;
  final int progress;
  final List<String> outstanding;
  final KycDraft draft;
  final List<KycDocumentInfo> documents;
  final List<KycHistoryEntry> history;
  final String? rejectionReason;
  final String? correctionNotes;
  final String phone;

  bool get isRestricted => status == 'RESTRICTED';
  bool get isVerified => status == 'APPROVED';
  bool get isPendingReview => status == 'PENDING_REVIEW';

  /// A restricted user can still edit and submit; only a submitted or
  /// approved record is locked.
  bool get canEdit => !isVerified && !isPendingReview;

  factory KycStatus.fromJson(Map<String, dynamic> j) => KycStatus(
        launched: j['launched'] == true,
        status: _str(j['status']) ?? 'NOT_STARTED',
        underlyingStatus: _str(j['underlyingStatus']) ??
            _str(j['status']) ??
            'NOT_STARTED',
        deadline: _date(j['deadline']),
        exemptUntil: _date(j['exemptUntil']),
        progress: _int(j['progress']),
        outstanding: j['outstanding'] is List
            ? [for (final e in j['outstanding'] as List) e.toString()]
            : <String>[],
        draft: KycDraft.fromJson(_map(j['draft'])),
        documents: _list(j['documents'], KycDocumentInfo.fromJson),
        history: _list(j['history'], KycHistoryEntry.fromJson),
        rejectionReason: _str(j['rejectionReason']),
        correctionNotes: _str(j['correctionNotes']),
        phone: _str(j['phone']) ?? '',
      );
}

class KycNotification {
  const KycNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory KycNotification.fromJson(Map<String, dynamic> j) => KycNotification(
        id: _str(j['id']) ?? '',
        kind: _str(j['kind']) ?? '',
        title: _str(j['title']) ?? '',
        body: _str(j['body']) ?? '',
        createdAt: _date(j['createdAt']),
        readAt: _date(j['readAt']),
      );
}
