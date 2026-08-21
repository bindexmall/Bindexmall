// ============================================================================
// MODEL: Address
// ============================================================================
// Merepresentasikan satu alamat pengiriman/penagihan milik user
// (nama penerima, no. HP, provinsi/kota/kecamatan, kode pos, alamat lengkap, dll).
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh AddressProvider & AddressRepository (disimpan lokal via SharedPreferences,
//  -   bukan tabel WooCommerce terpisah).
//  - toJson()/fromJson() untuk serialisasi ke local storage.
// ============================================================================

class Address {
  final String id;
  final String firstName;
  final String lastName;
  final String company;
  final String phone;
  final String email;
  final String country;
  final String address;
  final String apartment;
  final bool isDefault;
  
  // RajaOngkir Location Data (FULL HIERARCHY)
  final int? provinceId;
  final String? provinceName;
  final int? cityId;
  final String? cityName;
  final int? districtId;
  final String? districtName;
  final int? subdistrictId;
  final String? subdistrictName;
  final String? zipCode;

  Address({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.company = '',
    required this.phone,
    required this.email,
    this.country = 'Indonesia',
    required this.address,
    this.apartment = '',
    this.isDefault = false,
    this.provinceId,
    this.provinceName,
    this.cityId,
    this.cityName,
    this.districtId,
    this.districtName,
    this.subdistrictId,
    this.subdistrictName,
    this.zipCode,
  });

  String get fullName => '$firstName $lastName'.trim();
  
  String get fullAddress {
    final parts = [
      address,
      if (apartment.isNotEmpty) apartment,
      if (subdistrictName != null && subdistrictName!.isNotEmpty) subdistrictName,
      if (districtName != null && districtName!.isNotEmpty) districtName,
      if (cityName != null && cityName!.isNotEmpty) cityName,
      if (provinceName != null && provinceName!.isNotEmpty) provinceName,
      if (zipCode != null && zipCode!.isNotEmpty) zipCode,
      country,
    ];
    return parts.join(', ');
  }

  // Backward compatibility getters
  String get province => provinceName ?? '';
  String get city => cityName ?? '';
  String get district => districtName ?? '';
  String? get postalCode => zipCode;
  
  // For WooCommerce
  int? get destinationId => districtId; // Use district ID for shipping calculation

  String get destinationLabel {
    if (subdistrictName != null && districtName != null && cityName != null) {
      return '$subdistrictName, $districtName, $cityName';
    }
    if (districtName != null && cityName != null) {
      return '$districtName, $cityName';
    }
    if (cityName != null) {
      return cityName!;
    }
    return '';
  }

  bool get hasCompleteLocation {
    return provinceId != null &&
           cityId != null &&
           districtId != null;
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      company: json['company'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      country: json['country'] ?? 'Indonesia',
      address: json['address_1'] ?? json['address'] ?? '',
      apartment: json['address_2'] ?? json['apartment'] ?? '',
      isDefault: json['is_default'] ?? false,
      provinceId: json['province_id'] as int?,
      provinceName: json['province_name'] ?? json['state'],
      cityId: json['city_id'] as int?,
      cityName: json['city_name'] ?? json['city'],
      districtId: json['district_id'] as int?,
      districtName: json['district_name'],
      subdistrictId: json['subdistrict_id'] as int?,
      subdistrictName: json['subdistrict_name'],
      zipCode: json['zip_code'] ?? json['postcode'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'company': company,
      'phone': phone,
      'email': email,
      'country': country,
      'address_1': address,
      'address_2': apartment,
      'is_default': isDefault,
      'province_id': provinceId,
      'province_name': provinceName,
      'city_id': cityId,
      'city_name': cityName,
      'district_id': districtId,
      'district_name': districtName,
      'subdistrict_id': subdistrictId,
      'subdistrict_name': subdistrictName,
      'zip_code': zipCode,
      // Backward compatibility
      'state': provinceName,
      'city': cityName,
      'postcode': zipCode,
    };
  }

  Address copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? company,
    String? phone,
    String? email,
    String? country,
    String? address,
    String? apartment,
    bool? isDefault,
    int? provinceId,
    String? provinceName,
    int? cityId,
    String? cityName,
    int? districtId,
    String? districtName,
    int? subdistrictId,
    String? subdistrictName,
    String? zipCode,
  }) {
    return Address(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      country: country ?? this.country,
      address: address ?? this.address,
      apartment: apartment ?? this.apartment,
      isDefault: isDefault ?? this.isDefault,
      provinceId: provinceId ?? this.provinceId,
      provinceName: provinceName ?? this.provinceName,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      districtId: districtId ?? this.districtId,
      districtName: districtName ?? this.districtName,
      subdistrictId: subdistrictId ?? this.subdistrictId,
      subdistrictName: subdistrictName ?? this.subdistrictName,
      zipCode: zipCode ?? this.zipCode,
    );
  }

  @override
  String toString() {
    return 'Address(id: $id, name: $fullName, location: $destinationLabel)';
  }
}