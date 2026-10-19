class PatientDocument {
  final int? id;
  final int patientId;
  final String name;
  final String path;
  final bool isImage;
  final DateTime addedAt;

  PatientDocument({
    this.id,
    required this.patientId,
    required this.name,
    required this.path,
    required this.isImage,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'patient_id': patientId,
        'name': name,
        'path': path,
        'is_image': isImage ? 1 : 0,
        'added_at': addedAt.toIso8601String(),
      };

  factory PatientDocument.fromMap(Map<String, dynamic> m) => PatientDocument(
        id: m['id'] as int?,
        patientId: m['patient_id'] as int,
        name: m['name'] as String,
        path: m['path'] as String,
        isImage: (m['is_image'] as int) == 1,
        addedAt: DateTime.parse(m['added_at'] as String),
      );
}
