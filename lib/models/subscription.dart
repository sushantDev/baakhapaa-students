class SubscriptionResponse {
  final bool success;
  final String message;
  final List<SubscriptionPackage> data;

  SubscriptionResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => SubscriptionPackage.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SubscriptionPackage {
  final int id;
  final String title;
  final String description;
  final int pointsPerDay;
  final int pricePerDay;
  final double? priceUsdPerDay;
  final String? stripePriceId;
  final int levelId;
  final String createdAt;
  final String updatedAt;
  final List<Benefit> benefits;

  SubscriptionPackage({
    required this.id,
    required this.title,
    required this.description,
    required this.pointsPerDay,
    required this.pricePerDay,
    this.priceUsdPerDay,
    this.stripePriceId,
    required this.levelId,
    required this.createdAt,
    required this.updatedAt,
    required this.benefits,
  });

  factory SubscriptionPackage.fromJson(Map<String, dynamic> json) {
    return SubscriptionPackage(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      pointsPerDay: json['points_per_day'] ?? 0,
      pricePerDay: json['price_per_day'] ?? 0,
      priceUsdPerDay: (json['price_usd_per_day'] != null)
          ? double.tryParse(json['price_usd_per_day'].toString())
          : null,
      stripePriceId: json['stripe_price_id'],
      levelId: json['level_id'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      benefits: (json['benefits'] as List<dynamic>?)
              ?.map((item) => Benefit.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class Benefit {
  final int id;
  final int benefitTypeId;
  final String name;
  final String description;
  final int quantity;

  Benefit({
    required this.id,
    required this.benefitTypeId,
    required this.name,
    required this.description,
    required this.quantity,
  });

  factory Benefit.fromJson(Map<String, dynamic> json) {
    return Benefit(
      id: json['id'] ?? 0,
      benefitTypeId: json['benefit_type_id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      quantity: json['quantity'] ?? 0,
    );
  }

  /// Get benefit type name from benefit_type_id
  String getBenefitTypeName() {
    switch (benefitTypeId) {
      case 1:
        return 'Upgrade Level';
      case 2:
        return 'Unlock Stories';
      case 3:
        return 'Extra Lives';
      case 4:
        return 'Skip Timer';
      case 5:
        return 'Bypass Questions';
      case 6:
        return 'Unlock Achievement';
      case 7:
        return 'Unlock Challenge';
      default:
        return 'Unknown Benefit';
    }
  }
}

class PurchaseRequest {
  final int subscriptionId;
  final String duration;

  PurchaseRequest({
    required this.subscriptionId,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'subscription_id': subscriptionId,
      'duration': duration,
    };
  }
}

class PurchaseResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  PurchaseResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}

class UserBenefitStatusResponse {
  final bool success;
  final String message;
  final List<UserBenefitItem> items;

  UserBenefitStatusResponse({
    required this.success,
    required this.message,
    required this.items,
  });

  factory UserBenefitStatusResponse.fromJson(Map<String, dynamic> json) {
    return UserBenefitStatusResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      items: (json['data'] != null && json['data']['items'] != null)
          ? (json['data']['items'] as List<dynamic>)
              .map((item) => UserBenefitItem.fromJson(item))
              .toList()
          : [],
    );
  }
}

class UserBenefitItem {
  final int id;
  final Map<String, dynamic> subscription; // {id, title, price}
  final List<UserBenefitUsage> benefits;

  UserBenefitItem({
    required this.id,
    required this.subscription,
    required this.benefits,
  });

  factory UserBenefitItem.fromJson(Map<String, dynamic> json) {
    return UserBenefitItem(
      id: json['id'] ?? 0,
      subscription: json['subscription'] ?? {},
      benefits: (json['benefits'] as List<dynamic>?)
              ?.map((item) => UserBenefitUsage.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class UserBenefitUsage {
  final int id;
  final BenefitType benefitType;
  final Usage usage;
  final bool canUse;
  final String? lastBenefitUsedAt;

  UserBenefitUsage({
    required this.id,
    required this.benefitType,
    required this.usage,
    required this.canUse,
    this.lastBenefitUsedAt,
  });

  factory UserBenefitUsage.fromJson(Map<String, dynamic> json) {
    return UserBenefitUsage(
      id: json['id'] ?? 0,
      benefitType: BenefitType.fromJson(json['benefit_type'] ?? {}),
      usage: Usage.fromJson(json['usage'] ?? {}),
      canUse: json['can_use'] ?? false,
      lastBenefitUsedAt: json['last_benefit_used_at'],
    );
  }
}

class BenefitType {
  final int id;
  final String name;
  final String description;

  BenefitType({
    required this.id,
    required this.name,
    required this.description,
  });

  factory BenefitType.fromJson(Map<String, dynamic> json) {
    return BenefitType(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class Usage {
  final int usedCount;
  final int availableCount;
  final int remaining;
  final int displayRemaining;
  final bool isUnlimited;

  Usage({
    required this.usedCount,
    required this.availableCount,
    required this.remaining,
    required this.displayRemaining,
    required this.isUnlimited,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
      usedCount: json['used_count'] ?? 0,
      availableCount: json['available_count'] ?? 0,
      remaining: json['remaining'] ?? 0,
      displayRemaining: json['display_remaining'] ?? 0,
      isUnlimited: json['is_unlimited'] ?? false,
    );
  }
}

class UpdateUsageResponse {
  final bool success;
  final String message;
  final String? value;

  UpdateUsageResponse({
    required this.success,
    required this.message,
    this.value,
  });

  factory UpdateUsageResponse.fromJson(Map<String, dynamic> json) {
    return UpdateUsageResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      value: json['data'] != null ? json['data']['value'] : null,
    );
  }
}
