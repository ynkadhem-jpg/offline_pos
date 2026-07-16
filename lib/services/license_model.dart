enum LicenseType {
  trial,
  lifetime;

  String get storageValue {
    return switch (this) {
      LicenseType.trial => 'trial',
      LicenseType.lifetime => 'lifetime',
    };
  }

  String get arabicLabel {
    return switch (this) {
      LicenseType.trial => 'تجربة',
      LicenseType.lifetime => 'دائم',
    };
  }

  static LicenseType? parse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'trial' => LicenseType.trial,
      'lifetime' => LicenseType.lifetime,
      _ => null,
    };
  }
}

enum LicenseStatus { unactivated, active, trialExpired, clockTampered }
