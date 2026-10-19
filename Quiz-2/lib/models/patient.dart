class Patient {
  final int? id;
  final String name;
  final int age;
  final String gender;
  final String phone;
  final String email;
  final String address;
  final String bloodGroup;
  final String condition;
  final String notes;
  final String? imagePath;
  final DateTime createdAt;

  Patient({
    this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    this.email = '',
    this.address = '',
    this.bloodGroup = 'O+',
    this.condition = '',
    this.notes = '',
    this.imagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'phone': phone,
        'email': email,
        'address': address,
        'blood_group': bloodGroup,
        'condition': condition,
        'notes': notes,
        'image_path': imagePath,
        'created_at': createdAt.toIso8601String(),
      };

  factory Patient.fromMap(Map<String, dynamic> m) => Patient(
        id: m['id'] as int?,
        name: m['name'] as String,
        age: m['age'] as int,
        gender: m['gender'] as String,
        phone: m['phone'] as String,
        email: (m['email'] ?? '') as String,
        address: (m['address'] ?? '') as String,
        bloodGroup: (m['blood_group'] ?? 'O+') as String,
        condition: (m['condition'] ?? '') as String,
        notes: (m['notes'] ?? '') as String,
        imagePath: m['image_path'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
