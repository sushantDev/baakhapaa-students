class ShippingAddress {
  final int id;
  final int userId;
  final String recipientName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? stateProvince;
  final String postalCode;
  final String countryCode;
  final String countryName;
  final bool isDefault;

  const ShippingAddress({
    required this.id,
    required this.userId,
    required this.recipientName,
    required this.phone,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.stateProvince,
    required this.postalCode,
    required this.countryCode,
    required this.countryName,
    this.isDefault = false,
  });

  String get formattedAddress {
    final parts = [
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2!,
      city,
      if (stateProvince != null && stateProvince!.isNotEmpty) stateProvince!,
      postalCode,
      countryName,
    ];
    return parts.join(', ');
  }

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      recipientName: json['recipient_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      addressLine1: json['address_line1'] as String? ?? '',
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String? ?? '',
      stateProvince: json['state_province'] as String?,
      postalCode: json['postal_code'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      countryName: json['country_name'] as String? ?? '',
      isDefault: json['is_default'] == true || json['is_default'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'recipient_name': recipientName,
        'phone': phone,
        'address_line1': addressLine1,
        if (addressLine2 != null) 'address_line2': addressLine2,
        'city': city,
        if (stateProvince != null) 'state_province': stateProvince,
        'postal_code': postalCode,
        'country_code': countryCode,
        'country_name': countryName,
        'is_default': isDefault,
      };
}

class ShippingProvider {
  final int id;
  final String name;
  final String slug;
  final String? logo;
  final String? website;
  final String estimatedDelivery;
  final double costUsd;
  final double costNpr;
  final int estimatedDaysMin;
  final int estimatedDaysMax;

  const ShippingProvider({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    this.website,
    required this.estimatedDelivery,
    required this.costUsd,
    required this.costNpr,
    required this.estimatedDaysMin,
    required this.estimatedDaysMax,
  });

  factory ShippingProvider.fromJson(Map<String, dynamic> json) {
    return ShippingProvider(
      id: json['provider_id'] as int? ?? json['id'] as int? ?? 0,
      name: json['provider_name'] as String? ?? json['name'] as String? ?? '',
      slug: json['provider_slug'] as String? ?? json['slug'] as String? ?? '',
      logo: json['provider_logo'] as String?,
      website: json['provider_website'] as String?,
      estimatedDelivery: json['estimated_delivery'] as String? ?? '',
      costUsd: (json['cost_usd'] as num?)?.toDouble() ?? 0.0,
      costNpr: (json['cost_npr'] as num?)?.toDouble() ?? 0.0,
      estimatedDaysMin: json['estimated_days_min'] as int? ?? 0,
      estimatedDaysMax: json['estimated_days_max'] as int? ?? 0,
    );
  }
}

class OrderTrackingEvent {
  final int id;
  final String status;
  final String? location;
  final String? description;
  final DateTime eventAt;

  const OrderTrackingEvent({
    required this.id,
    required this.status,
    this.location,
    this.description,
    required this.eventAt,
  });

  factory OrderTrackingEvent.fromJson(Map<String, dynamic> json) {
    return OrderTrackingEvent(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      location: json['location'] as String?,
      description: json['description'] as String?,
      eventAt: DateTime.tryParse(json['event_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class OrderTracking {
  final int orderId;
  final String? trackingNumber;
  final String? trackingUrl;
  final String shippingStatus;
  final String? carrier;
  final String? carrierLogo;
  final DateTime? shippedAt;
  final DateTime? estimatedDelivery;
  final DateTime? deliveredAt;
  final Map<String, dynamic>? shippingAddress;
  final List<OrderTrackingEvent> events;

  const OrderTracking({
    required this.orderId,
    this.trackingNumber,
    this.trackingUrl,
    required this.shippingStatus,
    this.carrier,
    this.carrierLogo,
    this.shippedAt,
    this.estimatedDelivery,
    this.deliveredAt,
    this.shippingAddress,
    required this.events,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    final eventsJson = json['events'] as List<dynamic>? ?? [];
    return OrderTracking(
      orderId: json['order_id'] as int? ?? 0,
      trackingNumber: json['tracking_number'] as String?,
      trackingUrl: json['tracking_url'] as String?,
      shippingStatus: json['shipping_status'] as String? ?? 'pending',
      carrier: json['carrier'] as String?,
      carrierLogo: json['carrier_logo'] as String?,
      shippedAt: json['shipped_at'] != null
          ? DateTime.tryParse(json['shipped_at'])
          : null,
      estimatedDelivery: json['estimated_delivery'] != null
          ? DateTime.tryParse(json['estimated_delivery'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'])
          : null,
      shippingAddress: json['shipping_address'] as Map<String, dynamic>?,
      events: eventsJson
          .map((e) => OrderTrackingEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get statusLabel {
    switch (shippingStatus) {
      case 'pending':
        return 'Order Received';
      case 'processing':
        return 'Processing';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Shipped';
      case 'in_transit':
        return 'In Transit';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'returned':
        return 'Returned';
      case 'failed':
        return 'Delivery Failed';
      default:
        return 'Pending';
    }
  }
}
