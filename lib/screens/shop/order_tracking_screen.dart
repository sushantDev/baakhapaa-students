import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/shipping.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/header.dart';
import '../../utils/debug_logger.dart';

/// Order tracking screen — shows a timeline of shipping events for a given order.
///
/// Route arguments: `int` orderId
class OrderTrackingScreen extends StatefulWidget {
  static const routeName = '/order-tracking';

  const OrderTrackingScreen({Key? key}) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  Map<String, dynamic>? _trackingData;
  late int _orderId;
  var _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
      final args = ModalRoute.of(context)?.settings.arguments;
      _orderId = args is int ? args : int.tryParse(args.toString()) ?? 0;
      _fetchTracking();
    }
  }

  Future<void> _fetchTracking() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // DeliveryProvider is fetched directly here since we only need a one-shot call
      final delivery = DeliveryProviderAccessor.of(context);
      final data = await delivery.fetchOrderTracking(_orderId);

      if (!mounted) return;
      setState(() {
        _trackingData = data;
        _isLoading = false;
      });
    } catch (e) {
      DebugLogger.error('OrderTrackingScreen fetchTracking error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: 'Track Order #$_orderId'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError || _trackingData == null
              ? _buildError()
              : _buildContent(_trackingData!),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Could not load tracking info.',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchTracking,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final status = data['shipping_status'] as String? ?? 'pending';
    final trackingNumber = data['tracking_number'] as String?;
    final trackingUrl = data['tracking_url'] as String?;
    final carrier = data['carrier'] as String?;
    final carrierLogo = data['carrier_logo'] as String?;
    final estimatedDelivery = data['estimated_delivery'] != null
        ? DateTime.tryParse(data['estimated_delivery'])
        : null;
    final deliveredAt = data['delivered_at'] != null
        ? DateTime.tryParse(data['delivered_at'])
        : null;
    final addressData = data['shipping_address'] as Map<String, dynamic>?;

    final eventsRaw = data['events'] as List<dynamic>? ?? [];
    final events = eventsRaw
        .map((e) => OrderTrackingEvent.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.eventAt.compareTo(a.eventAt)); // Most recent first

    return RefreshIndicator(
      onRefresh: _fetchTracking,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status card ───────────────────────────────────────────────
            _StatusCard(
              status: status,
              carrier: carrier,
              carrierLogo: carrierLogo,
              trackingNumber: trackingNumber,
              trackingUrl: trackingUrl,
              estimatedDelivery: estimatedDelivery,
              deliveredAt: deliveredAt,
            ),
            const SizedBox(height: 20),

            // ── Delivery address ──────────────────────────────────────────
            if (addressData != null) ...[
              _buildAddressCard(addressData),
              const SizedBox(height: 20),
            ],

            // ── Timeline ──────────────────────────────────────────────────
            const Text(
              'Tracking History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (events.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.hourglass_empty,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No tracking updates yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              _TrackingTimeline(events: events),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> data) {
    final lines = <String>[
      if (data['recipient_name'] != null) data['recipient_name'] as String,
      if (data['address_line1'] != null) data['address_line1'] as String,
      if (data['address_line2'] != null) data['address_line2'] as String,
      [
        if (data['city'] != null) data['city'] as String,
        if (data['state_province'] != null) data['state_province'] as String,
        if (data['postal_code'] != null) data['postal_code'] as String,
      ].where((s) => s.isNotEmpty).join(', '),
      if (data['country_name'] != null) data['country_name'] as String,
    ].where((s) => s.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined,
              color: Colors.deepPurple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                ...lines.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(l,
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Card ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String status;
  final String? carrier;
  final String? carrierLogo;
  final String? trackingNumber;
  final String? trackingUrl;
  final DateTime? estimatedDelivery;
  final DateTime? deliveredAt;

  const _StatusCard({
    required this.status,
    this.carrier,
    this.carrierLogo,
    this.trackingNumber,
    this.trackingUrl,
    this.estimatedDelivery,
    this.deliveredAt,
  });

  static const _statusOrder = [
    'pending',
    'processing',
    'packed',
    'shipped',
    'in_transit',
    'out_for_delivery',
    'delivered',
  ];

  Color _colorFor(String s) {
    switch (s) {
      case 'delivered':
        return Colors.green;
      case 'in_transit':
      case 'out_for_delivery':
        return Colors.blue;
      case 'shipped':
        return Colors.indigo;
      case 'failed':
      case 'returned':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _iconFor(String s) {
    switch (s) {
      case 'pending':
        return Icons.schedule;
      case 'processing':
        return Icons.settings_outlined;
      case 'packed':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'in_transit':
        return Icons.flight_takeoff_outlined;
      case 'out_for_delivery':
        return Icons.two_wheeler_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline;
      case 'returned':
        return Icons.keyboard_return;
      default:
        return Icons.help_outline;
    }
  }

  String _labelFor(String s) {
    switch (s) {
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
      case 'failed':
        return 'Delivery Failed';
      case 'returned':
        return 'Returned';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    final icon = _iconFor(status);
    final label = _labelFor(status);
    final currentIdx = _statusOrder.indexOf(status);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (estimatedDelivery != null && status != 'delivered')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Est. delivery: ${_formatDate(estimatedDelivery!)}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                    if (deliveredAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Delivered on ${_formatDate(deliveredAt!)}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.green.shade700),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Progress bar (only for main flow statuses, not failed/returned)
          if (currentIdx >= 0) ...[
            const SizedBox(height: 20),
            Row(
              children: List.generate(_statusOrder.length, (i) {
                final isCompleted = i <= currentIdx;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                        right: i < _statusOrder.length - 1 ? 3 : 0),
                    decoration: BoxDecoration(
                      color: isCompleted ? color : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ],

          const SizedBox(height: 16),

          // Carrier info
          if (carrier != null || trackingNumber != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            if (carrier != null)
              _infoRow(Icons.local_shipping_outlined, 'Carrier', carrier!),
            if (trackingNumber != null)
              _infoRow(Icons.qr_code_outlined, 'Tracking No.', trackingNumber!),
            if (trackingUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(trackingUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('Track on ${carrier ?? "Carrier"} website'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─── Tracking Timeline ────────────────────────────────────────────────────────

class _TrackingTimeline extends StatelessWidget {
  final List<OrderTrackingEvent> events;

  const _TrackingTimeline({required this.events});

  Color _colorForStatus(String s) {
    switch (s) {
      case 'delivered':
        return Colors.green;
      case 'in_transit':
      case 'out_for_delivery':
        return Colors.blue;
      case 'shipped':
        return Colors.indigo;
      case 'failed':
      case 'returned':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _iconForStatus(String s) {
    switch (s) {
      case 'pending':
        return Icons.schedule;
      case 'processing':
        return Icons.settings_outlined;
      case 'packed':
        return Icons.inventory_2_outlined;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'in_transit':
        return Icons.flight_takeoff_outlined;
      case 'out_for_delivery':
        return Icons.two_wheeler_outlined;
      case 'delivered':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'returned':
        return Icons.keyboard_return;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(events.length, (i) {
        final event = events[i];
        final isFirst = i == 0;
        final isLast = i == events.length - 1;
        final color = _colorForStatus(event.status);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline spine
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 16,
                      color:
                          isFirst ? Colors.transparent : Colors.grey.shade300,
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.12),
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Icon(_iconForStatus(event.status),
                          size: 16, color: color),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color:
                            isLast ? Colors.transparent : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Event content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isFirst
                        ? color.withOpacity(0.05)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFirst
                          ? color.withOpacity(0.3)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labelFor(event.status),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isFirst ? color : null,
                        ),
                      ),
                      if (event.location != null &&
                          event.location!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 13, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                event.location!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.description!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _formatDateTime(event.eventAt),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _labelFor(String s) {
    switch (s) {
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
      case 'failed':
        return 'Delivery Failed';
      case 'returned':
        return 'Returned';
      default:
        return s;
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }
}

// ─── Helper to access DeliveryProvider without listen ────────────────────────

class DeliveryProviderAccessor {
  static DeliveryProvider of(BuildContext context) {
    return Provider.of<DeliveryProvider>(context, listen: false);
  }
}
