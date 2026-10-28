class AccountModel {
  const AccountModel({
    required this.username,
    required this.displayName,
    required this.role,
    required this.uid,
    required this.createdBy,
    required this.createdAt,
    this.trialDuration = 'permanent',
    this.trialExpiry,
  });

  final String username;
  final String displayName;
  final String role;
  final String uid;
  final String createdBy;
  final String? createdAt;
  final String trialDuration;
  final String? trialExpiry;

  factory AccountModel.fromJson(Map<String, dynamic> json) => AccountModel(
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? json['username']?.toString() ?? '',
        role: json['role']?.toString() ?? 'member',
        uid: json['uid']?.toString() ?? '-',
        createdBy: json['createdBy']?.toString() ?? '-',
        createdAt: json['createdAt']?.toString(),
        trialDuration: json['trialDuration']?.toString() ?? 'permanent',
        trialExpiry: json['trialExpiry']?.toString(),
      );
}