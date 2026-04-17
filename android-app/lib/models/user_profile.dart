class UserProfile {
  String name;
  String surname;
  String email;
  String phone;
  bool savingMode;
  int minThreshold;
  int maxThreshold;

  UserProfile({
    this.name = '--',
    this.surname = '--',
    this.email = '--',
    this.phone = '--',
    this.savingMode = false,
    this.minThreshold = 15,
    this.maxThreshold = 80,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'surname': surname,
      'email': email,
      'phone': phone,
      'savingMode': savingMode,
      'minThreshold': minThreshold,
      'maxThreshold': maxThreshold,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? '--',
      surname: map['surname'] ?? '--',
      email: map['email'] ?? '--',
      phone: map['phone'] ?? '--',
      savingMode: map['savingMode'] ?? false,
      minThreshold: map['minThreshold'] ?? 15,
      maxThreshold: map['maxThreshold'] ?? 80,
    );
  }
}
