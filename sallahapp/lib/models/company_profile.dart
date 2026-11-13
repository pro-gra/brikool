/// A partner company profile — a real business (aluminum, electrical
/// wiring, painting, construction, etc.) that handles large-scale
/// projects. Companies self-register with their own account (same
/// phone-auth flow as clients/technicians) and see their own incoming
/// quote requests. Admin can still verify/feature/manage any company.
class CompanyProfile {
  const CompanyProfile({
    required this.companyId,
    required this.name,
    this.logoUrl,
    this.coverPhotoUrl,
    this.portfolioUrls = const [],
    required this.description,
    this.categories = const [],
    required this.city,
    required this.phone,
    this.email = '',
    this.priceRangeMin = 0,
    this.priceRangeMax = 0,
    this.yearsInBusiness = 0,
    this.isVerified = false,
    this.isActive = true,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.projectsCompleted = 0,
    this.onboardingComplete = false,
    this.walletBalance = 0,
  });

  final String companyId;
  final String name;
  final String? logoUrl;
  final String? coverPhotoUrl;
  final List<String> portfolioUrls;
  final String description;
  final List<String> categories; // BigServiceCategory ids
  final String city;
  final String phone;
  final String email;
  final double priceRangeMin;
  final double priceRangeMax;
  final int yearsInBusiness;
  final bool isVerified;
  final bool isActive;
  final double rating;
  final int reviewCount;
  final int projectsCompleted;
  final bool onboardingComplete;
  final double walletBalance;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'coverPhotoUrl': coverPhotoUrl,
      'portfolioUrls': portfolioUrls,
      'description': description,
      'categories': categories,
      'city': city,
      'phone': phone,
      'email': email,
      'priceRangeMin': priceRangeMin,
      'priceRangeMax': priceRangeMax,
      'yearsInBusiness': yearsInBusiness,
      'isVerified': isVerified,
      'isActive': isActive,
      'rating': rating,
      'reviewCount': reviewCount,
      'projectsCompleted': projectsCompleted,
      'onboardingComplete': onboardingComplete,
      'walletBalance': walletBalance,
    };
  }

  static CompanyProfile fromMap(String id, Map<String, dynamic> map) {
    return CompanyProfile(
      companyId: id,
      name: map['name'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      coverPhotoUrl: map['coverPhotoUrl'] as String?,
      portfolioUrls: (map['portfolioUrls'] as List?)?.cast<String>() ?? [],
      description: map['description'] as String? ?? '',
      categories: (map['categories'] as List?)?.cast<String>() ?? [],
      city: map['city'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      priceRangeMin: (map['priceRangeMin'] as num?)?.toDouble() ?? 0,
      priceRangeMax: (map['priceRangeMax'] as num?)?.toDouble() ?? 0,
      yearsInBusiness: (map['yearsInBusiness'] as num?)?.toInt() ?? 0,
      isVerified: map['isVerified'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      projectsCompleted: (map['projectsCompleted'] as num?)?.toInt() ?? 0,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0,
    );
  }

  CompanyProfile copyWith({
    String? name,
    String? logoUrl,
    String? coverPhotoUrl,
    List<String>? portfolioUrls,
    String? description,
    List<String>? categories,
    String? city,
    String? phone,
    String? email,
    double? priceRangeMin,
    double? priceRangeMax,
    int? yearsInBusiness,
    bool? isVerified,
    bool? isActive,
    bool? onboardingComplete,
    double? walletBalance,
    int? reviewCount,
  }) {
    return CompanyProfile(
      companyId: companyId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      portfolioUrls: portfolioUrls ?? this.portfolioUrls,
      description: description ?? this.description,
      categories: categories ?? this.categories,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      priceRangeMin: priceRangeMin ?? this.priceRangeMin,
      priceRangeMax: priceRangeMax ?? this.priceRangeMax,
      yearsInBusiness: yearsInBusiness ?? this.yearsInBusiness,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      rating: rating,
      reviewCount: reviewCount ?? this.reviewCount,
      projectsCompleted: projectsCompleted,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}