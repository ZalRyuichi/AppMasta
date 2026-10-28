class RoleConfig {
  static const order = ['developer', 'owner', 'partner', 'reseller', 'member'];

  static const canCreate = {
    'developer': ['owner', 'partner', 'reseller', 'member'],
    'owner': ['partner', 'reseller', 'member'],
    'partner': ['reseller', 'member'],
    'reseller': ['member'],
    'member': <String>[],
  };

  static const sellerCanCreate = canCreate;

  static bool canSellerCreate(String role) => (sellerCanCreate[role] ?? []).isNotEmpty;

  static const roleLabels = {
    'member': 'Member',
    'reseller': 'Reseller',
    'partner': 'Partner',
    'owner': 'Owner',
    'developer': 'Developer',
  };

  static const productPrices = {
    'member': 50000,
    'reseller': 250000,
    'partner': 375000,
    'owner': 500000,
  };

  static List<String> trialOptions(String myRole, String targetRole) {
    if (targetRole == 'member') {
      if (myRole == 'developer') {
        return ['3m', '5m', '10m', '3d', '7d', '30d', 'permanent'];
      }
      if (myRole == 'owner' || myRole == 'partner') return ['3d', '7d', '30d', 'permanent'];
      if (myRole == 'reseller') return ['30d', 'permanent'];
      return [];
    }
    if (targetRole == 'reseller' || targetRole == 'partner') {
      if (myRole == 'developer' || myRole == 'owner') return ['30d', 'permanent'];
      return ['permanent'];
    }
    return ['permanent'];
  }

  static String trialLabel(String value) {
    return switch (value) {
      '3m' => '3 Menit',
      '5m' => '5 Menit',
      '10m' => '10 Menit',
      '3d' => '3 Hari',
      '7d' => '1 Minggu',
      '30d' => '1 Bulan',
      'permanent' => 'Permanent',
      _ => value,
    };
  }

  static bool canDelete(String myRole, String targetRole, String myUsername, String targetUsername) {
    if (targetUsername == myUsername) return false;
    final myIdx = order.indexOf(myRole);
    final targetIdx = order.indexOf(targetRole);
    return myIdx != -1 && targetIdx != -1 && myIdx < targetIdx;
  }
}