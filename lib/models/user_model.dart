class UserModel {
  const UserModel({
    required this.username,
    required this.displayName,
    required this.role,
    required this.uid,
    this.trialExpiry,
    this.hasAvatar = false,
  });

  final String username;
  final String displayName;
  final String role;
  final String uid;
  final String? trialExpiry;
  final bool hasAvatar;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? json['username']?.toString() ?? '',
        role: json['role']?.toString() ?? 'member',
        uid: json['uid']?.toString() ?? '',
        trialExpiry: json['trialExpiry']?.toString(),
        hasAvatar: json['hasAvatar'] == true,
      );

  UserModel copyWith({bool? hasAvatar}) => UserModel(
        username: username,
        displayName: displayName,
        role: role,
        uid: uid,
        trialExpiry: trialExpiry,
        hasAvatar: hasAvatar ?? this.hasAvatar,
      );
}