class Student {
  final int? id;
  final String name;
  final String rollNo;
  final String department;
  final String semester;
  final String phone;

  const Student({
    this.id,
    required this.name,
    required this.rollNo,
    required this.department,
    required this.semester,
    required this.phone,
  });

  /// Convert Student instance into a Map for SQLite database operations
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'roll_no': rollNo.trim().toUpperCase(),
      'department': department.trim(),
      'semester': semester.trim(),
      'phone': phone.trim(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Create a Student instance from a SQLite database Map
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      rollNo: (map['roll_no'] ?? '') as String,
      department: (map['department'] ?? '') as String,
      semester: (map['semester'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
    );
  }

  /// Create a copy of Student with updated fields
  Student copyWith({
    int? id,
    String? name,
    String? rollNo,
    String? department,
    String? semester,
    String? phone,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      phone: phone ?? this.phone,
    );
  }

  @override
  String toString() {
    return 'Student(id: $id, name: $name, rollNo: $rollNo, department: $department, semester: $semester, phone: $phone)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student &&
        other.id == id &&
        other.name == name &&
        other.rollNo == rollNo &&
        other.department == department &&
        other.semester == semester &&
        other.phone == phone;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        rollNo.hashCode ^
        department.hashCode ^
        semester.hashCode ^
        phone.hashCode;
  }
}
